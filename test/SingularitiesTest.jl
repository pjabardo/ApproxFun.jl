using ApproxFun, Base.Test


x=Fun(identity);
@test_approx_eq sqrt(cos(π/2*x))[.1] sqrt(cos(.1π/2))


x=Fun(identity,[-2.,2.])
u=sqrt(4-x.^2)/(2π)
@test_approx_eq u[.1] sqrt(4-.1^2)/(2π)
@test_approx_eq sum(u) 1


f=Fun(x->x.*cot(π*x/2))
x=Fun(identity)
u=Fun((f./(1-x.^2)).coefficients,JacobiWeightSpace(1.,1.,Interval()))
@test_approx_eq 1./(.1.*cot(π*.1/2)) (1./u)[.1]

@test_approx_eq (x./u)[.1] tan(π*.1/2)


f=Fun(x->exp(-x.^2),Line(0.,0.,-.5,-.5),400)
@test_approx_eq sum(f) sqrt(π)

f=Fun(x->exp(x)/sqrt(1-x.^2),JacobiWeightSpace(-.5,-.5))
println(f[.1] - (exp(.1)/sqrt(1-.1^2)))
@test_approx_eq f[.1] (x->exp(x)/sqrt(1-x.^2))(.1)
