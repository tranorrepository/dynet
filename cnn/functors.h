#ifndef CNN_GPU_FUNCTORS_H
#define CNN_GPU_FUNCTORS_H

#if HAVE_CUDA
#  define CNN_DEVICE_FUNC __device__
#else
#  define CNN_DEVICE_FUNC
#endif

// these functions are used both in CPU and in GPU computation
// this file may be compiled with NVCC or a standard C++ tool.
// if you need a new elementwise (nullary, unary, binary...)
// functor, this is the place for it

namespace cnn {

struct FConstantMinus {
  FConstantMinus(float c) : c(c) {}
  CNN_DEVICE_FUNC inline float operator()(float x) const {
    return c - x;
  }
  float c;
};

struct FNegate {
  CNN_DEVICE_FUNC inline float operator()(float x) const {
    return -x;
  }
};

struct FTanh {
  CNN_DEVICE_FUNC inline float operator()(float x) const {
    return tanhf(x);
  }
};

struct FTanhBackward {
  CNN_DEVICE_FUNC inline float operator()(float t, float d) const {
    return (1.f - t * t) * d;
  }
};

struct FPairwiseRankLoss {
  FPairwiseRankLoss(float m) : margin(m) {}
  CNN_DEVICE_FUNC float operator()(float a, float b) const {
    float d = margin - a + b;
    return d > 0.f ? d : 0.f;
  }
  float margin;
};

struct FRectifyBackward {
  CNN_DEVICE_FUNC inline float operator()(float t, float d) const {
    return (t) ? d : 0.f;
  }
};

struct FSoftmaxNormalize {
  explicit FSoftmaxNormalize(float logz) : logz(logz) {}
  CNN_DEVICE_FUNC inline float operator()(float x) const {
    return expf(x - logz);
  }
  float logz;
};

struct FSoftmaxBackward {
  explicit FSoftmaxBackward(float off_diag_sum) : off_diag_sum(off_diag_sum) {}
  CNN_DEVICE_FUNC inline float operator()(float t, float d) const {
    return (off_diag_sum + d) * t;
  }
  float off_diag_sum;
};

struct FNegLogSoftmaxBackward {
  FNegLogSoftmaxBackward(float lz, float err) : logz(lz), d(err) {}
  CNN_DEVICE_FUNC inline float operator()(float t) const {
    return expf(t - logz) * d;
  }
  float logz;
  float d;
};

struct FLogSoftmaxNormalize {
  explicit FLogSoftmaxNormalize(float logz) : logz(logz) {}
  CNN_DEVICE_FUNC inline float operator()(float x) const {
    return x - logz;
  }
  float logz;
};

struct FWeightedError {
  float operator()(float t, float d) const {
    return expf(t) * d / expf(t);
  }
};

struct FLogSoftmaxBackward {
  explicit FLogSoftmaxBackward(float off_diag_sum) : off_diag_sum(off_diag_sum) {}
  CNN_DEVICE_FUNC inline float operator()(float t, float d) const {
    return off_diag_sum * expf(t) + d;
    //return (off_diag_sum + d) * t;
  }
  float off_diag_sum;
};

struct FRectify {
  CNN_DEVICE_FUNC inline float operator()(float x) const {
    return (x > 0.f) ? x : 0.f;
  }
};

struct FLogisticSigmoid {
  CNN_DEVICE_FUNC inline float operator()(float x) const {
    return 1.f / (1.f + expf(-x));
  }
};

struct FLogisticSigmoidBackward {
  CNN_DEVICE_FUNC inline float operator()(float t, float d) const {
    return (1.f - t) * t * d;
  }
};

struct FSqDist {
  CNN_DEVICE_FUNC inline float operator()(float a, float b) const {
    float d = a - b;
    return d * d;
  }
};

struct FEuclideanBackward {
  FEuclideanBackward(int i, const float* s) : i(i), scalar(s) {}
  CNN_DEVICE_FUNC inline float operator()(float a, float b) const {
    return (i == 0 ? 2.f : -2.f) * (*scalar) * (a - b);
  }
  int i;
  const float* scalar;
};

struct FL2SGDUpdate {
  FL2SGDUpdate(float l, float s) : lambda(l), scale(-s) {}
  CNN_DEVICE_FUNC inline float operator()(float x, float g) const {
    return scale * g - x * lambda;
  }
  float lambda;
  float scale;
};

} // namespace cnn

#endif
