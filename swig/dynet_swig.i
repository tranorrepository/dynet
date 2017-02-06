%module dynet_swig

// This module provides java bindings for the dynet C++ code

// Automatically load the library code
%pragma(java) jniclasscode=%{
    static {
        System.loadLibrary("dynet_swig");
    }
%}

// Required header files for compiling wrapped code
%{
#include <vector>
#include <sstream>
#include <boost/archive/text_oarchive.hpp>
#include <boost/archive/text_iarchive.hpp>
#include "model.h"
#include "tensor.h"
#include "dynet.h"
#include "training.h"
#include "expr.h"
#include "rnn.h"
#include "lstm.h"
%}

// Extra C++ code added
%{
namespace dynet {

// Convenience function for testing
static void myInitialize()  {
  char** argv = {NULL};
  int argc = 0;
  initialize(argc, argv);
};
}
%}

//
// Macro to generate extra vector constructors that take a java Collection,
// needs to be declared + used before we include "std_vector.i"
//

%define VECTORCONSTRUCTOR(ctype, javatype, vectortype)
%typemap(javacode) std::vector<ctype> %{
  public vectortype(java.util.Collection<javatype> values) {
     this(values.size());
     int i = 0;
     for (java.util.Iterator<javatype> it = values.iterator(); it.hasNext(); i++) {
         javatype value = it.next();
         this.set(i, value);
     }
  }
%}
%enddef

VECTORCONSTRUCTOR(float, Float, FloatVector)
VECTORCONSTRUCTOR(double, Double, DoubleVector)
VECTORCONSTRUCTOR(int, Integer, IntVector)
VECTORCONSTRUCTOR(unsigned, Integer, UnsignedVector)
VECTORCONSTRUCTOR(dynet::expr::Expression, Expression, ExpressionVector)

// Useful SWIG libraries
%include "std_vector.i"
%include "std_string.i"
%include "std_pair.i"
%include "cpointer.i"

%pointer_functions(unsigned, uintp);
%pointer_functions(int, intp);
%pointer_functions(float, floatp);

struct dynet::expr::Expression;

// Declare explicit types for needed instantiations of generic types
namespace std {
  %template(IntVector)        vector<int>;
  %template(UnsignedVector)   vector<unsigned>;
  %template(DoubleVector)     vector<double>;
  %template(FloatVector)      vector<float>;
  %template(LongVector)       vector<long>;
  %template(StringVector)     vector<std::string>;
  %template(ExpressionVector) vector<dynet::expr::Expression>;
}

//
// The subset of classes/methods/functions we want to wrap
//

namespace dynet {

// Some declarations etc to keep swig happy
typedef float real;
typedef int RNNPointer;
struct VariableIndex;
/*{
  unsigned t;
  explicit VariableIndex(const unsigned t_): t(t_) {};
};*/
struct Tensor;
struct Node;
struct ParameterStorage;
struct LookupParameterStorage;

///////////////////////////////////
// declarations from dynet/dim.h //
///////////////////////////////////

%rename(get) Dim::operator[];

%typemap(javacode) Dim %{
  public Dim(long... values) {
    this();

    int i = 0;
    for (long l: values) {
      this.resize(i + 1);
      this.set(i, l);
      i++;
    }
  }

  @Override
  public boolean equals(Object obj) {
    // must be the same class
    if (obj instanceof $javaclassname) {
      $javaclassname other = ($javaclassname)obj;
      // must have the same shapes
      if (this.ndims() != other.ndims() ||
          this.batch_elems() != other.batch_elems()) return false;

      // must have the same values for every dim
      for (int i = 0; i < this.ndims(); i++) {
        if (this.get(i) != other.get(i)) return false;
      }

      return true;
    }
    return false;
  }

  @Override
  public int hashCode() {
    int hash = 17 * (int)this.ndims() + (int)this.batch_elems();
    for (int i = 0; i < this.ndims(); i++) {
      hash = hash * 31 + (int)this.get(i);
    }
    return hash;
  }
%}

struct Dim {
  Dim() : nd(0), bd(1) {}
  Dim(const std::vector<long> & x);
  Dim(const std::vector<long> & x, unsigned int b);

  unsigned int size();
  unsigned int batch_size();
  unsigned int sum_dims();

  Dim truncate();
  Dim single_batch();

  void resize(unsigned int i);
  unsigned int ndims();
  unsigned int rows();
  unsigned int cols();
  unsigned int batch_elems();
  void set(unsigned int i, unsigned int s);
  unsigned int operator[](unsigned int i);
  unsigned int size(unsigned int i);

  void delete_dim(unsigned int i);

  Dim transpose();
};

/////////////////////////////////////
// declarations from dynet/model.h //
/////////////////////////////////////

// Model wrapper class needs to implement Serializable. We serialize a Model by converting it
// to/from a String and using writeObject/readObject on the String.
%typemap(javainterfaces) dynet::Model "java.io.Serializable"

%typemap(javacode) dynet::Model %{
 private void writeObject(java.io.ObjectOutputStream out) throws java.io.IOException {
    out.defaultWriteObject();
    String s = this.serialize_to_string();
    out.writeObject(s);
 }

 private void readObject(java.io.ObjectInputStream in)
     throws java.io.IOException, java.lang.ClassNotFoundException {
    in.defaultReadObject();
    String s = (String) in.readObject();

    // Deserialization doesn't call the constructor, so the swigCPtr is 0. This means we need to
    // do the constructor work ourselves if we don't want a segfault.
    if (this.swigCPtr == 0) {
        this.swigCPtr = dynet_swigJNI.new_Model();
        this.swigCMemOwn = true;
    }

    this.load_from_string(s);
 }
%}

class Model;
struct Parameter {
  Parameter();
  Parameter(Model* mp, unsigned long index);
  void zero();
  Model* mp;
  unsigned long index;

  Dim dim();
  Tensor* values();

  void set_updated(bool b);
  bool is_updated();

};

struct LookupParameter {
  LookupParameter();
  LookupParameter(Model* mp, unsigned long index);
  LookupParameterStorage* get() const;
  void initialize(unsigned index, const std::vector<float>& val) const;
  void zero();
  Model* mp;
  unsigned long index;
  Dim dim() { return get()->dim; }
  std::vector<Tensor>* values() { return &(get()->values); }
  void set_updated(bool b);
  bool is_updated();
};

/*
struct LookupParameterStorage : public ParameterStorageBase {
  void scale_parameters(float a) override;
  void zero() override;
  void squared_l2norm(float* sqnorm) const override;
  void g_squared_l2norm(float* sqnorm) const override;
  size_t size() const override;
  void initialize(unsigned index, const std::vector<float>& val);
  void accumulate_grad(unsigned index, const Tensor& g);
  void clear();
  void initialize_lookups();
  Dim all_dim;
  Tensor all_values;
  Tensor all_grads;
  Dim dim;
  std::vector<Tensor> values;
  std::vector<Tensor> grads;
  std::unordered_set<unsigned> non_zero_grads;
};
*/

struct ParameterInit {
  ParameterInit() {}
  virtual ~ParameterInit() {}
  virtual void initialize_params(Tensor & values) const = 0;
};

struct ParameterInitNormal : public ParameterInit {
  ParameterInitNormal(float m = 0.0f, float v = 1.0f) : mean(m), var(v) {}
  virtual void initialize_params(Tensor& values) const override;
 private:
  float mean, var;
};

struct ParameterInitUniform : public ParameterInit {
  ParameterInitUniform(float scale) :
    left(-scale), right(scale) { assert(scale != 0.0f); }
  ParameterInitUniform(float l, float r) : left(l), right(r) { assert(l != r); }
  virtual void initialize_params(Tensor & values) const override;
 private:
  float left, right;
};

struct ParameterInitConst : public ParameterInit {
  ParameterInitConst(float c) : cnst(c) {}
  virtual void initialize_params(Tensor & values) const override;
private:
  float cnst;
};

struct ParameterInitIdentity : public ParameterInit {
  ParameterInitIdentity() {}
  virtual void initialize_params(Tensor & values) const override;
};

struct ParameterInitGlorot : public ParameterInit {
  ParameterInitGlorot(bool is_lookup = false) : lookup(is_lookup) {}
  virtual void initialize_params(Tensor & values) const override;
private:
  bool lookup;
};

/* I AM NOT ACTUALLY IMPLEMENTED IN THE DYNET CODE
struct ParameterInitSaxe : public ParameterInit {
  ParameterInitSaxe() {}
  virtual void initialize_params(Tensor & values) const override;
private:
  float cnst;
};
*/

struct ParameterInitFromFile : public ParameterInit {
  ParameterInitFromFile(std::string f) : filename(f) {}
  virtual void initialize_params(Tensor & values) const override;
private:
  std::string filename;
};

struct ParameterInitFromVector : public ParameterInit {
  ParameterInitFromVector(std::vector<float> v) : vec(v) {}
  virtual void initialize_params(Tensor & values) const override;
private:
  std::vector<float> vec;
};


class Model {
 public:
  Model();
  ~Model();
  float gradient_l2_norm() const;
  void reset_gradient();

  Parameter add_parameters(const Dim& d, float scale = 0.0f);
  // Parameter add_parameters(const Dim& d, const ParameterInit & init);
  LookupParameter add_lookup_parameters(unsigned n, const Dim& d);
  // LookupParameter add_lookup_parameters(unsigned n, const Dim& d, const ParameterInit & init);

  size_t parameter_count() const;
};

void save_dynet_model(std::string filename, Model* model);
void load_dynet_model(std::string filename, Model* model);

// extra code to serialize / deserialize strings
%extend Model {
   std::string serialize_to_string() {
       std::ostringstream out;
       boost::archive::text_oarchive oa(out);
       oa << (*($self));
       return out.str();
   }

   void load_from_string(std::string serialized) {
       std::istringstream in;
       in.str(serialized);
       boost::archive::text_iarchive ia(in);
       ia >> (*($self));
   }
};

//////////////////////////////////////
// declarations from dynet/tensor.h //
//////////////////////////////////////

struct Tensor {
  Dim d;
  float* v;
  std::vector<Tensor> bs;
};

real as_scalar(const Tensor& t);
std::vector<real> as_vector(const Tensor& v);

struct TensorTools {
  static float AccessElement(const Tensor& v, const Dim& index);
};

/////////////////////////////////////
// declarations from dynet/nodes.h //
/////////////////////////////////////

struct Sum;
struct LogSumExp;
struct AffineTransform;
struct ConcatenateColumns;
struct Concatenate;
struct Average;

////////////////////////////////////
// declarations from dynet/expr.h //
////////////////////////////////////


struct ComputationGraph;

namespace expr {
struct Expression {
  ComputationGraph *pg;
  VariableIndex i;
  Expression(ComputationGraph *pg, VariableIndex i) : pg(pg), i(i) { };
  const Tensor& value();
  const Dim& dim() const { return pg->get_dimension(i); }
};

// This template gets used to instantiate operations on vector<Expression>
namespace detail {
template <typename F, typename T> Expression f(const T& xs);
}

/* INPUT OPERATIONS */

Expression input(ComputationGraph& g, real s);
Expression input(ComputationGraph& g, const real *ps);
//Expression input(ComputationGraph& g, const Dim& d, const std::vector<float>& data);
Expression input(ComputationGraph& g, const Dim& d, const std::vector<float>* pdata);
Expression input(ComputationGraph& g, const Dim& d, const std::vector<unsigned int>& ids, const std::vector<float>& data, float defdata = 0.f);
Expression parameter(ComputationGraph& g, Parameter p);
Expression const_parameter(ComputationGraph& g, Parameter p);
Expression lookup(ComputationGraph& g, LookupParameter p, unsigned index);
Expression lookup(ComputationGraph& g, LookupParameter p, const unsigned* pindex);
Expression const_lookup(ComputationGraph& g, LookupParameter p, unsigned index);
Expression const_lookup(ComputationGraph& g, LookupParameter p, const unsigned* pindex);
Expression lookup(ComputationGraph& g, LookupParameter p, const std::vector<unsigned>& indices);
//Expression lookup(ComputationGraph& g, LookupParameter p, const std::vector<unsigned>* pindices);
//Expression const_lookup(ComputationGraph& g, LookupParameter p, const std::vector<unsigned>& indices);
Expression const_lookup(ComputationGraph& g, LookupParameter p, const std::vector<unsigned>* pindices);

Expression zeroes(ComputationGraph& g, const Dim& d);
Expression random_normal(ComputationGraph& g, const Dim& d);
Expression random_bernoulli(ComputationGraph& g, const Dim& d, real p, real scale = 1.0f);
Expression random_uniform(ComputationGraph& g, const Dim& d, real left, real right);

/* ARITHMETIC OPERATIONS */

// Rename operators to valid Java function names
%rename(exprPlus) operator+;
%rename(exprTimes) operator*;
%rename(exprMinus) operator-;
%rename(exprDivide) operator/;

Expression operator-(const Expression& x);
Expression operator+(const Expression& x, const Expression& y);
Expression operator+(const Expression& x, real y);
Expression operator+(real x, const Expression& y);
Expression operator-(const Expression& x, const Expression& y);
Expression operator-(real x, const Expression& y);
Expression operator-(const Expression& x, real y);
Expression operator*(const Expression& x, const Expression& y);
Expression operator*(const Expression& x, float y);
Expression operator*(float y, const Expression& x); // { return x * y; }
Expression operator/(const Expression& x, float y); // { return x * (1.f / y); }

// TODO(joelgrus) rename these without the VE
%template(affine_transform_VE) detail::f<AffineTransform, std::vector<Expression>>;
%template(sum) detail::f<Sum, std::vector<Expression>>;
%template(average) detail::f<Average, std::vector<Expression>>;

Expression sqrt(const Expression& x);
Expression erf(const Expression& x);
Expression tanh(const Expression& x);
Expression exp(const Expression& x);
Expression square(const Expression& x);
Expression cube(const Expression& x);
Expression lgamma(const Expression& x);
Expression log(const Expression& x);
Expression logistic(const Expression& x);
Expression rectify(const Expression& x);
Expression softsign(const Expression& x);
Expression pow(const Expression& x, const Expression& y);

Expression min(const Expression& x, const Expression& y);

// We need two overloaded versions of `max`, but apparently %template
// gets unhappy when you use it to overload a function, so we have to define
// the `ExpressionVector` version of `max` explicitly.
%{
namespace dynet { namespace expr {
Expression max(const std::vector<Expression>& xs) {
  return detail::f<Max, std::vector<Expression>>(xs);
};
} }
%}

Expression max(const Expression& x, const Expression& y);
Expression max(const std::vector<Expression>& xs);
Expression dot_product(const Expression& x, const Expression& y);
Expression cmult(const Expression& x, const Expression& y);
Expression cdiv(const Expression& x, const Expression& y);
Expression colwise_add(const Expression& x, const Expression& bias);

/* PROBABILITY / LOSS OPERATIONS */

Expression softmax(const Expression& x);
Expression log_softmax(const Expression& x);
Expression log_softmax(const Expression& x, const std::vector<unsigned>& restriction);

%template(logsumexp) detail::f<LogSumExp, std::vector<Expression>>;

// TODO(joelgrus): delete this once no one is using it
%template(logsumexp_VE) detail::f<LogSumExp, std::vector<Expression>>;

Expression pickneglogsoftmax(const Expression& x, unsigned v);
Expression pickneglogsoftmax(const Expression& x, const unsigned* pv);
Expression pickneglogsoftmax(const Expression& x, const std::vector<unsigned>& v);

Expression hinge(const Expression& x, unsigned index, float m = 1.0);
Expression hinge(const Expression& x, unsigned* pindex, float m = 1.0);
Expression hinge(const Expression& x, const std::vector<unsigned>& indices, float m = 1.0);

Expression sparsemax(const Expression& x);
Expression sparsemax_loss(const Expression& x, const std::vector<unsigned>& target_support);

Expression squared_norm(const Expression& x);
Expression squared_distance(const Expression& x, const Expression& y);
Expression l1_distance(const Expression& x, const Expression& y);
Expression huber_distance(const Expression& x, const Expression& y, float c = 1.345f);
Expression binary_log_loss(const Expression& x, const Expression& y);
Expression pairwise_rank_loss(const Expression& x, const Expression& y, real m = 1.0);
Expression poisson_loss(const Expression& x, unsigned y);
Expression poisson_loss(const Expression& x, const unsigned* py);

/* FLOW / SHAPING OPERATIONS */

Expression nobackprop(const Expression& x);
Expression reshape(const Expression& x, const Dim& d);
Expression transpose(const Expression& x);
Expression select_rows(const Expression& x, const std::vector<unsigned> &rows);
Expression select_cols(const Expression& x, const std::vector<unsigned> &cols);
Expression sum_batches(const Expression& x);

Expression pick(const Expression& x, unsigned v, unsigned d = 0);
Expression pick(const Expression& x, const std::vector<unsigned>& v, unsigned d = 0);
Expression pick(const Expression& x, const unsigned* v, unsigned d = 0);
Expression pickrange(const Expression& x, unsigned v, unsigned u);

%template(concatenate_cols) detail::f<ConcatenateColumns, std::vector<Expression>>;
%template(concatenate) detail::f<Concatenate, std::vector<Expression>>;

// TODO(joelgrus): delete these once no one is using them
%template(concatenate_cols_VE) detail::f<ConcatenateColumns, std::vector<Expression>>;
%template(concatenate_VE) detail::f<Concatenate, std::vector<Expression>>;

/* NOISE OPERATIONS */

Expression noise(const Expression& x, real stddev);
Expression dropout(const Expression& x, real p);
Expression block_dropout(const Expression& x, real p);

/* CONVOLUTION OPERATIONS */

Expression conv1d_narrow(const Expression& x, const Expression& f);
Expression conv1d_wide(const Expression& x, const Expression& f);
Expression filter1d_narrow(const Expression& x, const Expression& f);
Expression kmax_pooling(const Expression& x, unsigned k);
Expression fold_rows(const Expression& x, unsigned nrows=2);
Expression sum_dim(const Expression& x, unsigned d);
Expression sum_cols(const Expression& x);
Expression sum_rows(const Expression& x);
Expression average_cols(const Expression& x);
Expression kmh_ngram(const Expression& x, unsigned n);

/* TENSOR OPERATIONS */

Expression contract3d_1d(const Expression& x, const Expression& y);
Expression contract3d_1d_1d(const Expression& x, const Expression& y, const Expression& z);
Expression contract3d_1d_1d(const Expression& x, const Expression& y, const Expression& z, const
 Expression& b);
Expression contract3d_1d(const Expression& x, const Expression& y, const Expression& b);

/* LINEAR ALGEBRA OPERATIONS */

Expression inverse(const Expression& x);
Expression logdet(const Expression& x);
Expression trace_of_product(const Expression& x, const Expression& y);

} // namespace expr

/////////////////////////////////////
// declarations from dynet/dynet.h //
/////////////////////////////////////

struct ComputationGraph {
  ComputationGraph();
  ~ComputationGraph();

  VariableIndex add_input(real s);
  // VariableIndex add_input(const real* ps);
  VariableIndex add_input(const Dim& d, const std::vector<float>& data);
  //VariableIndex add_input(const Dim& d, const std::vector<float>* pdata);
  VariableIndex add_input(const Dim& d, const std::vector<unsigned int>& ids, const std::vector<float>& data, float defdata = 0.f);

  VariableIndex add_parameters(Parameter p);
  VariableIndex add_const_parameters(Parameter p);
  VariableIndex add_lookup(LookupParameter p, const unsigned* pindex);
  VariableIndex add_lookup(LookupParameter p, unsigned index);
  VariableIndex add_lookup(LookupParameter p, const std::vector<unsigned>* pindices);
  // VariableIndex add_lookup(LookupParameter p, const std::vector<unsigned>& indices);
  VariableIndex add_const_lookup(LookupParameter p, const unsigned* pindex);
  VariableIndex add_const_lookup(LookupParameter p, unsigned index);
  VariableIndex add_const_lookup(LookupParameter p, const std::vector<unsigned>* pindices);
  // VariableIndex add_const_lookup(LookupParameter p, const std::vector<unsigned>& indices);

  void clear();
  void checkpoint();
  void revert();

  Dim& get_dimension(VariableIndex index) const;

  const Tensor& forward(const expr::Expression& last);
  //const Tensor& forward(VariableIndex i);
  const Tensor& incremental_forward(const expr::Expression& last);
  //const Tensor& incremental_forward(VariableIndex i);
  //const Tensor& get_value(VariableIndex i);
  const Tensor& get_value(const expr::Expression& e);
  void invalidate();
  void backward(const expr::Expression& last);
  //void backward(VariableIndex i);

  void print_graphviz() const;

  std::vector<Node*> nodes;
  std::vector<VariableIndex> parameter_nodes;
};

////////////////////////////////////////
// declarations from dynet/training.h //
////////////////////////////////////////

// Need to disable constructor as SWIG gets confused otherwise
%nodefaultctor Trainer;
struct Trainer {
  void update(real scale = 1.0);
  void update_epoch(real r = 1);
  void rescale_and_reset_weight_decay();
  real eta0;
  real eta;
  real eta_decay;
  real epoch;
  real clipping_enabled;
  real clip_threshold;
  real clips;
  real updates;
  bool aux_allocated;

  void status();

  Model* model;
};

struct SimpleSGDTrainer : public Trainer {
  explicit SimpleSGDTrainer(Model& m, real e0 = 0.1, real edecay = 0.0) : Trainer(m, e0, edecay) {}
};

struct AdamTrainer : public Trainer {
  explicit AdamTrainer(Model& m, float e0 = 0.001, float beta_1 = 0.9, float beta_2 = 0.999, float eps = 1e-8, real edecay = 0.0) :
    Trainer(m, e0, edecay), beta_1(beta_1), beta_2(beta_2), epsilon(eps) {}
};

///////////////////////////////////
// declarations from dynet/rnn.h //
///////////////////////////////////

%nodefaultctor RNNBuilder;
struct RNNBuilder {
  RNNPointer state() const;
  void new_graph(ComputationGraph& cg);
  void start_new_sequence(const std::vector<dynet::expr::Expression>& h_0 = {});
  dynet::expr::Expression set_h(const RNNPointer& prev, const std::vector<dynet::expr::Expression>& h_new = {});
  dynet::expr::Expression set_s(const RNNPointer& prev, const std::vector<dynet::expr::Expression>& s_new = {});
  dynet::expr::Expression add_input(const dynet::expr::Expression& x);
  dynet::expr::Expression add_input(const RNNPointer& prev, const dynet::expr::Expression& x);
  std::vector<dynet::expr::Expression> final_s() const;
  std::vector<dynet::expr::Expression> final_h() const;
};

////////////////////////////////////
// declarations from dynet/lstm.h //
////////////////////////////////////

struct LSTMBuilder : public RNNBuilder {
  //LSTMBuilder() = default;
  explicit LSTMBuilder(unsigned layers,
                       unsigned input_dim,
                       unsigned hidden_dim,
                       Model& model);
};

// LSTMBuilder has a .back() method that returns an Expression struct *by value*
// It turns out that SWIG has a really hard time dealing with return-by-value. It returns a
// "pointer" wrapper (SWIGTYPE_p_Expression) that cannot be dereferenced from Java. As a somewhat
// hacky workaround, we add methods that return the two elements of that struct, and then in
// DynetScalaHelpers we use implicits to add a `back()` method that behaves like the built-in
// one should.
%extend LSTMBuilder {
  ComputationGraph* back_graph() { return $self->back().pg; }
  VariableIndex back_index() { return $self->back().i; }
};

////////////////////////////////////
// declarations from dynet/init.h //
////////////////////////////////////

void initialize(int& argc, char**& argv, bool shared_parameters = false);
void cleanup();

/////////////////////////////
// additional declarations //
/////////////////////////////

static void myInitialize();

}






