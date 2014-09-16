

export FourierSpace,TaylorSpace,HardySpace,CosSpace,SinSpace,LaurentSpace

for T in (:CosSpace,:SinSpace)
    @eval begin
        immutable $T <: PeriodicDomainSpace
            domain::Union(PeriodicDomain,AnyDomain)
        end
        ==(a::($T),b::($T))= a.domain==b.domain
    end
end

# s == true means analytic inside, taylor series
# s == false means anlytic outside and decaying at infinity
immutable HardySpace{s} <: PeriodicDomainSpace
    domain::Union(PeriodicDomain,AnyDomain)
end

=={s}(a::HardySpace{s},b::HardySpace{s})= a.domain==b.domain

typealias TaylorSpace HardySpace{true}
typealias PoleSpace HardySpace{false}

transform(::TaylorSpace,vals::Vector)=alternatesign!(fft(vals)/length(vals))
itransform(::TaylorSpace,cfs::Vector)=ifft(alternatesign!(cfs))*length(cfs)

transform(::PoleSpace,vals::Vector)=-alternatesign!(flipud(fft(vals))/length(vals))
itransform(::PoleSpace,cfs::Vector)=ifft(flipud(alternatesign!(-cfs)))*length(cfs)

function evaluate{T}(f::Fun{T,TaylorSpace},z)
    d=domain(f)
    if typeof(d) <: Circle
        horner(f.coefficients,(z-d.center)/d.radius)
    else
        horner(f.coefficients,fromcanonical(Circle(),tocanonical(f,z)))
    end
end

function evaluate{T}(f::Fun{T,PoleSpace},z)
    d=domain(f)
    if typeof(d) <: Circle
        z=(z-d.center)/d.radius
        z=1./z
        z.*horner(f.coefficients,z)
    else
        z=fromcanonical(Circle(),tocanonical(f,z))
        z=1./z
        z.*horner(f.coefficients,z)
    end
end


##TODO: fast routine
function horner{T}(v::Vector{T},z)
    ret = zero(T)
    ei = z*one(T)
    
    p = one(T)
    for vk in v
        ret += vk*p
        p *= ei
    end
    
    ret
end

## Cos and Sin space

points(sp::CosSpace,n)=points(domain(sp),2n-2)[1:n]
transform(::CosSpace,vals)=chebyshevtransform(vals)
itransform(::CosSpace,cfs)=ichebyshevtransform(cfs)
evaluate{T}(f::Fun{T,CosSpace},t)=clenshaw(f.coefficients,cos(tocanonical(f,t)))


points(sp::SinSpace,n)=fromcanonical(domain(sp),(π*[1:n])/(n+1))
transform(::SinSpace,vals)=FFTW.r2r(vals,FFTW.RODFT00)/(length(vals)+1)
itransform(::SinSpace,cfs)=FFTW.r2r(cfs,FFTW.RODFT00)/2
evaluate{T}(f::Fun{T,SinSpace},t)=sum([f.coefficients[k]*sin(k*tocanonical(f,t)) for k=1:length(f)])



## Laurent space

typealias LaurentSpace PeriodicSumSpace{HardySpace{true},HardySpace{false}}
LaurentSpace(d::Union(PeriodicDomain,AnyDomain))=PeriodicSumSpace((HardySpace{true}(d),HardySpace{false}(d)))

Space(d::PeriodicDomain)=LaurentSpace(d)
canonicalspace(S::PeriodicDomainSpace)=LaurentSpace(domain(S))


points(sp::LaurentSpace,n)=points(domain(sp),n)
transform(::LaurentSpace,vals)=svfft(vals)|>interlace
itransform(::LaurentSpace,cfs)=isvfft(deinterlace(cfs))

## Ones and zeros


for op in (:(Base.ones),:(Base.zeros))
    @eval ($op){T<:Number}(::Type{T},S::LaurentSpace)=Fun(($op)(T,1),S)
end


## Fourier space

typealias FourierSpace PeriodicSumSpace{CosSpace,SinSpace}
FourierSpace(d::Union(PeriodicDomain,AnyDomain))=PeriodicSumSpace((CosSpace(d),SinSpace(d)))

points(sp::FourierSpace,n)=points(domain(sp),n)
function transform{T<:Number}(::FourierSpace,vals::Vector{T})
    n=length(vals)
    cfs=2FFTW.r2r(vals, FFTW.R2HC )/n
    cfs[1]/=2
    if iseven(n)
        cfs[n/2+1]/=2
        for k=2:2:n/2+1
            cfs[k]*=-1
        end  
    else
        for k=2:2:(n+1)/2
            cfs[k]*=-1
        end     
    end
    if mod(n,4)==0
        for k=n/2+3:2:n
            cfs[k]*=-1
        end
    elseif mod(n,4)==2
        for k=n/2+2:2:n
            cfs[k]*=-1
        end    
    elseif mod(n,4)==1
        for k=(n+3)/2:2:n
            cfs[k]*=-1
        end   
    else #mod(n,4)==3
        for k=(n+5)/2:2:n
            cfs[k]*=-1
        end      
    end
        
    ret=Array(T,n)
    if iseven(n)
        ret[1:2:end]=cfs[1:n/2]
        ret[2:2:end]=cfs[end:-1:n/2+1]
    else
        ret[1:2:end]=cfs[1:(n+1)/2]
        ret[2:2:end]=cfs[end:-1:(n+3)/2]
    end
    ret    
end







##Differentiation and integration


differentiate{T}(f::Fun{T,LaurentSpace})=Fun(interlace(fourierdiff(domain(f),deinterlace(f.coefficients))),f.space)
Base.sum{T}(f::Fun{T,LaurentSpace})=fouriersum(domain(f),deinterlace(f.coefficients))
integrate{T}(f::Fun{T,LaurentSpace})=Fun(interlace(fourierintegrate(domain(f),deinterlace(f.coefficients))),f.space)


fourierdiff(d::PeriodicInterval,cfs::ShiftVector)=tocanonicalD(d,0)*ShiftVector(1.im*[firstindex(cfs):-1],1.im*[0:lastindex(cfs)]).*cfs




function fourierintegrate(d::PeriodicInterval,cfs::ShiftVector)
    tol = 10eps()
    @assert abs(cfs[0]) < tol
    
    ##TODO: mapped domains
    
    @assert d.a ==-π
    @assert d.b ==π        
    ShiftVector(-1.im./[firstindex(cfs):-1],
                [0,(-1.im./[1:lastindex(cfs)])])
end

fouriersum(d::PeriodicInterval,cfs::ShiftVector)=cfs[0].*length(d)



function fourierdiff(d::Circle,cfs::ShiftVector)
        ##TODO: general radii
        @assert d.radius == 1.
        @assert d.center == 0

        # Now shift everything by one
        ShiftVector(
                        [([firstindex(cfs):-1].*cfs[firstindex(cfs):-1]),0],
                        [1:lastindex(cfs)].*cfs[1:lastindex(cfs)]
                        )
end



function fourierintegrate(d::Circle,cfs::ShiftVector)
    tol = 10eps()
    @assert abs(cfs[-1]) < tol        
    ##TODO: general radii        
    @assert d.radius == 1.
    @assert d.center == 0        
    
    # Now shift everything by one
    ShiftVector(
                    [cfs[firstindex(cfs):-1]./[firstindex(cfs):-1]],
                    [0,(cfs[0:lastindex(cfs)]./[1:lastindex(cfs)+1])]
                    )
end


function fouriersum{T}(d::Circle,cfs::ShiftVector{T})
    @assert d.radius == 1.
    @assert d.center == 0   
    if firstindex(cfs) <= -1
        cfs[-1]
    else
        zero(T)
    end
end




include("FourierOperators.jl")