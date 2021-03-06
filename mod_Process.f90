MODULE ModProcess
implicit none


!! important convention for 1-loop amplitudes:
!! external quarks need to be Str/AStr or Top/ATop
!! massive quarks (i.e. tops) in closed fermion loops are Bot
!! massless quarks in closed fermion loops are Chm


type :: Particle
   integer  :: PartType
   integer  :: ExtRef
   integer  :: Helicity
   real(8)  :: Mass
   real(8)  :: Mass2
   complex(8) :: Mom(1:8)
   complex(8) :: Pol(1:16)
end type

type :: Propagator
   integer  :: PartType
   integer  :: ExtRef
   real(8)  :: Mass
   real(8)  :: Mass2
   complex(8) :: Mom(1:8)
end type

type :: PtrToParticle
   integer,pointer  :: PartType
   integer,pointer  :: ExtRef
   real(8),pointer  :: Mass
   real(8),pointer  :: Mass2
   integer ,pointer :: Helicity
   complex(8),pointer :: Mom(:)
   complex(8),pointer :: Pol(:)
end type



type :: TreeProcess
   integer :: NumPart
   integer :: NumQua
   integer :: NumSca
   integer :: NumW
   integer :: NumV
   integer :: BosonVertex
   integer,allocatable :: NumGlu(:)
   integer,allocatable :: PartRef(:)
   integer,allocatable :: PartType(:)
   type(PtrToParticle),allocatable :: Quarks(:)
   type(PtrToParticle),allocatable :: Gluons(:)
   type(PtrToParticle) :: Boson
   type(PtrToParticle),allocatable :: Scalars(:)
!    procedure(), pointer, nopass :: EvalCurrent
end type



type :: AMatch
  integer, allocatable :: NumMatch(:)                    ! the first index labels the sister
  integer, allocatable :: MatchHiCuts(:,:)!  the first index labels the sister: 0=prim.amp itself, 1..NumSister labels the sisters, the second index labels the the matching higher cuts, e.g. for 3-cut (1,2,4) the number of the matching 4-cuts are 1 and 3
  integer, allocatable :: FirstHiProp(:,:)! the first index labels the sister
  integer, allocatable :: MissHiProp(:,:,:)! the first index labels the sister
end type

type :: UCutMatch
  type(AMatch) :: Subt(2:5)
end type



type :: UnitarityCut
   integer              :: CutType              ! 5,...,1: pent.,...,sing. cut
   integer              :: NumCuts              ! number of cuts
   integer, allocatable :: CutProp(:,:)         ! CutProp(cut number, 1..CutType): cut prop. in highest-level diagr.
   complex(8),  allocatable :: Coeff(:,:)        ! coefficients of these cuts
   complex(16), allocatable :: Coeff_128(:,:)        ! coefficients of these cuts
   type(TreeProcess), allocatable :: TreeProcess(:,:)  ! process for a cut at a vertex, first and last number are the prop.ID, the rest corresp. to the ExtParticle ID
   real(8), allocatable :: KMom(:,:,:)
   complex(8), allocatable :: NMom(:,:,:)
   logical, allocatable  :: skip(:)                 ! If the cut is a duplicate, set this to true and don't compute anything
   type(UCutMatch),allocatable :: Match(:)      ! for matching a cut with higher cuts, array includes all cuts
   integer,allocatable  :: tagcuts(:)
end type

type :: PrimitiveAmplitude
   integer :: NPoint                            ! highest level of loop diagram
   integer :: AmpType                             ! J=0/1/2: subset of closed scalar loop/all other/fermion loop
   integer :: FermLoopPart                      ! fermion type in closed loop
   integer, allocatable :: ExtLine(:)        ! sequence of ext. particles
   type(Propagator), allocatable :: IntPart(:)   ! internal particle, i.e. propagator particle
   integer :: FermionLines                      ! number of quark lines
   integer :: FermLine1In                       ! vertex number of beginning of 1st quark line
   integer :: FermLine1Out                      ! vertex number of termination of 1st quark line
   integer :: FermLine2In                       ! vertex number of beginning of 2nd quark line
   integer :: FermLine2Out                      ! vertex number of termination of 2nd quark line
   integer :: ScalarLines                       ! number of scalar lines
   integer :: ScaLine1In                        ! vertex number of beginning of 1st scalar line
   integer :: ScaLine1Out                       ! vertex number of termination of 1st scalar line
   type(UnitarityCut) :: UCuts(1:5)             ! unitarity cuts for this prim.ampl.
   complex(8) :: Result(-2:1)
!    integer :: NumInsertions1                    ! number of insertions of colorless particles in quark line 1 (corresp. to NCut)
!    integer :: NumInsertions2                    ! number of insertions of colorless particles in quark line 2
!    type(TreeProcess) :: TreeProc                ! tree amplitude
   integer,allocatable :: Sisters(:)               ! sister primitive amplitudes for ttb+Z
   integer :: NumSisters
end type

type :: BornAmplitude
   integer, allocatable :: ExtLine(:)        ! sequence of ext. particles
   type(TreeProcess) :: TreeProc             ! tree amplitude
   complex(8) :: Result
end type


type(Particle),allocatable, target :: ExtParticle(:)
integer,allocatable :: Helicities(:,:)
type(PrimitiveAmplitude),allocatable, target :: PrimAmps(:)
type(BornAmplitude),allocatable, target :: BornAmps(:)

integer, public :: NumExtParticles,NumHelicities,NumPrimAmps,NumBornAmps
!integer, public :: tag_Z
integer h1,h2,h3,h4,h5,h6,ih


contains




SUBROUTINE InitProcess()
use ModParameters
use ModMisc
implicit none
real(8) :: QuarkCrossing=-1d0, SpinAvg=1d0/4d0, QuarkColAvg=1d0/3d0, GluonColAvg=1d0/8d0, SymmFact=1d0/2d0
include "vegas_common.f"


NDim = 0
IF( abs(TOPDECAYS).GE.1 ) THEN
  NDim = NDim + 4+4
ENDIF

IF( (ZDECAYS.GE.1 .and. ZDECAYS.LE.9) .or. ZDECAYS.EQ.-1 ) THEN
  NDim = NDim + 2
ELSEIF( ZDECAYS.GE.10 ) then
  NDim = NDim + 3
ENDIF

IF( TOPDECAYS.EQ.5 .OR. TOPDECAYS.EQ.6 ) THEN
  NDim = NDim + 1
  IF(CORRECTION.EQ.4) THEN
      NDim = NDim + 1
  ENDIF
ENDIF

IF(HelSampling) THEN
  NDim = NDim + 1
ENDIF

m_SMTop = m_Top

IF( PROCESS.EQ.0 ) THEN !   3_Glu  + 4_Glu  --> 5_Glu  + 1_Glu  + 2_Glu + 6_Glu
  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,-1,-2,3,4/)
      MasterProcess=0
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 8
      VegasNc0_default = 0
      VegasNc1_default = 2
  ELSEIF( CORRECTION.EQ.1 ) THEN
      NumExtParticles = 7
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/6,7,-1,-2,3,4,5/)
      MasterProcess=0
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 11
      VegasNc0_default = 0
      VegasNc1_default = 10
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.1 ) THEN !   3_Glu  + 4_Glu  --> 1_ATop + 2_Top
  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=1
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.1 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=1
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 50000
      VegasNc1_default = 50000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=1
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.5 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=1
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 3+3  ! additional gluons in the top decay
!                                      NDIM = NDIM + 8  ! ADDITIONAL GLUONS IN THE TOP DECAY WITH SEPARATE YRND!!!!!!!
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.2 ) THEN !   3_Str  + 4_AStr --> 1_ATop + 2_Top
  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.1 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 50000
      VegasNc1_default = 50000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.5 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 3+3  ! additional gluons in the top decay
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.3 ) THEN !   3_Str  + 5_Glu  --> 4_Str  + 1_ATop + 2_Top
  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,3,-2/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000
      VegasNc1_default = 10000
  ELSEIF( CORRECTION.EQ.1 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,3,-2/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 0
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,3,-2/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,3,-2/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.4 ) THEN !   4_AStr + 5_Glu  --> 3_AStr + 1_ATop + 2_Top
  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,3,-2,-1/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000
      VegasNc1_default = 10000
  ELSEIF( CORRECTION.EQ.1 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,3,-2,-1/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 0
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,3,-1,-2/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,3,-2,-1/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.5 ) THEN !   3_Glu  + 4_Glu  --> 5_Glu  + 1_ATop + 2_Top
  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=3
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000
      VegasNc1_default = 10000
  ELSEIF( CORRECTION.EQ.1 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=3
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 0
      VegasNc1_default = 10
  ELSEIF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=3
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 20000000
      VegasNc1_default = 20000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=1
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=3
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.6 ) THEN !   3_Str  + 4_AStr --> 5_Glu  + 1_ATop + 2_Top
  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000
      VegasNc1_default = 10000

!       NumExtParticles = 4!!!   this is for run of ttbar + jet from decay
!       allocate(Crossing(1:NumExtParticles))
!       allocate(ExtParticle(1:NumExtParticles))
!       Crossing(:) = (/3,4,-1,-2/)
!       MasterProcess=2
!       AvgFactor = SpinAvg * QuarkColAvg**2
!       NDim = NDim + 2    ! t tbar PS integration
!       NDim = NDim + 2    ! shat integration
!       ndim =ndim + 3 ! jet
!       VegasNc0_default = 10000000
!       VegasNc1_default = 10000000


  ELSEIF( CORRECTION.EQ.1 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 0
      VegasNc1_default = 10

  ELSEIF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 20000000
      VegasNc1_default = 20000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF




ELSEIF( PROCESS.EQ.7 .OR. PROCESS.EQ.8 ) THEN !   Top/ATop decay width


  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 1
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      IF( PROCESS.EQ.7 ) MasterProcess=45! Atop decay
      IF( PROCESS.EQ.8 ) MasterProcess=46! Top decay
      NDim = 4    ! PS integration
      VegasNc0_default = 200000
      VegasNc1_default = 200000
!   ELSEIF( CORRECTION.EQ.4 ) THEN
!       NumExtParticles = 3
!       allocate(Crossing(1:NumExtParticles))
!       allocate(ExtParticle(1:NumExtParticles))
!       IF( PROCESS.EQ.7 ) MasterProcess=45
!       IF( PROCESS.EQ.8 ) MasterProcess=46
!       NDim = NDim + 2    ! st PS integration
!       NDim = NDim + 4    ! fake t PS integration
! !       NDim = NDim + 1    ! for dummy integration
!       VegasNc0_default = 200000
!       VegasNc1_default = 200000
!   ELSEIF( CORRECTION.EQ.5 ) THEN
!       NumExtParticles = 4
!       allocate(Crossing(1:NumExtParticles))
!       allocate(ExtParticle(1:NumExtParticles))
!       IF( PROCESS.EQ.7 ) MasterProcess=45
!       IF( PROCESS.EQ.8 ) MasterProcess=46
!       NDim = NDim + 2    ! st PS integration
!       NDim = NDim + 3    ! real gluon
!       NDim = NDim + 4    ! fake t PS integration
!       VegasNc0_default = 200000
!       VegasNc1_default = 200000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF

  

ELSEIF( PROCESS.EQ.9 ) THEN !   3_Glu  + 4_Glu  --> 5_Glu  + 6_Glu  + 1_ATop + 2_Top
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,-1,-2,3,4/)
      MasterProcess=5
      AvgFactor = SpinAvg * GluonColAvg**2 * SymmFact
      NDim = NDim + 8    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000

  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=3
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 500000
      VegasNc1_default = 500000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF

ELSEIF( PROCESS.EQ.10 ) THEN !   3_Str  + 4_AStr --> 5_Glu  + 6_Glu  + 1_ATop + 2_Top
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,-1,-2,3,4/)
      MasterProcess=6
      AvgFactor = SpinAvg * QuarkColAvg**2  * SymmFact
      NDim = NDim + 8    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000

  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.11 ) THEN !   5_Glu  + 6_Glu --> 3_Str  + 4_AStr + 1_ATop + 2_Top
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,3,4,-1,-2/)
      MasterProcess=6
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 8    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000

  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,3,-1,-2/)
      MasterProcess=3
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 500000
      VegasNc1_default = 500000

  ELSE
      call Error("Correction to this process is not available")
  ENDIF


ELSEIF( PROCESS.EQ.12 ) THEN !   3_Str + 5_Glu --> 4_Str  + 1_ATop + 2_Top + 6_Glu
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,-1,3,-2,4/)
      MasterProcess=6
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 8    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000

  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,3,-2/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000

  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.13 ) THEN !   4_AStr + 5_Glu --> 3_Str  + 1_ATop + 2_Top + 6_Glu
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,3,-1,-2,4/)
      MasterProcess=6
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 8    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000

  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,3,-1,-2/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF


ELSEIF( PROCESS.EQ.14 ) THEN !   3_Str + 4_AStr -->  5_Chm + 6_AChm + 1_ATop + 2_Top //  5_Str + 6_AStr + 1_ATop + 2_Top
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,-1,-2,3,4/)
      MasterProcess=7
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 8    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000

  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,3,-1,-2/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg*QuarkColAvg
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000

  ELSE
      call Error("Correction to this process is not available")
  ENDIF


ELSEIF( PROCESS.EQ.15 ) THEN !   3_Str + 6_AChm -->  4_Str + 5_AChm + 1_ATop + 2_Top
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,-1,3,4,-2/)
      MasterProcess=7
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 8    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000000
      VegasNc1_default = 50

  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,3,-2/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg*QuarkColAvg
      NDim = NDim + 5    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000

  ELSE
      call Error("Correction to this process is not available")
  ENDIF


ELSEIF( PROCESS.EQ.16 ) THEN !   3_Str + 6_Chm -->  4_Str + 5_Chm + 1_ATop + 2_Top
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,-1,3,-2,4/)
      MasterProcess=7
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 8    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000000
      VegasNc1_default = 50

  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,3,-2/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg*QuarkColAvg
      NDim = NDim + 5    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000

  ELSE
      call Error("Correction to this process is not available")
  ENDIF


ELSEIF( PROCESS.EQ.17 ) THEN !   4_AStr + 5_AChm -->  3_AStr + 5_AChm + 1_ATop + 2_Top
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,3,-1,4,-2/)
      MasterProcess=7
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 8    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000000
      VegasNc1_default = 50

  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,3,-1,-2/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg*QuarkColAvg
      NDim = NDim + 5    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF


ELSEIF( PROCESS.EQ.18 ) THEN !   3_Chm + 5_Chm -->  4_Chm + 6_Chm + 1_ATop + 2_Top
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,-1,3,-2,4/)
      MasterProcess=7
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 8    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000000
      VegasNc1_default = 50

  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,3,-2/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg*QuarkColAvg
      NDim = NDim + 5    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000

  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.19 ) THEN !   4_AChm + 6_AChm -->  3_AChm + 5_AChm + 1_ATop + 2_Top
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,3,-1,4,-2/)
      MasterProcess=7
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 8    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000000
      VegasNc1_default = 50

  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-3,-1,-2/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg*QuarkColAvg
      NDim = NDim + 5    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000

  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.20 ) THEN !   3_Glu  + 4_Glu  --> 1_ATop + 2_Top + 5_Pho(in production)
  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      if( TTBPhoton_SMonly ) then
        MasterProcess=8
      else
        MasterProcess=17    
      endif
      NDim = NDim + 5    ! PS integration
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.1 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      if( TTBPhoton_SMonly ) then
        MasterProcess=8
      else
        MasterProcess=17    
      endif 
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=8
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.5 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=8
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 3  ! additional gluons in the top decay
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF


ELSEIF( PROCESS.EQ.21 ) THEN !   3_Glu  + 4_Glu  --> 1_ATop + 2_Top + 5_Pho(in decay)
  IF( CORRECTION.LE.1 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=1
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 3    ! photon phase space
      NDim = NDim + 2    ! shat integration
      if( Unweighted ) NDim=NDim+1   ! variable to decide which nPhoRad
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=1
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.5 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=1
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 3    ! additional gluons in the top decay
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF


ELSEIF( PROCESS.EQ.22 ) THEN !   3_Str  + 4_AStr --> 1_ATop + 2_Top + 5_Pho(in production)
  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      if( TTBPhoton_SMonly ) then
        MasterProcess=9
      else
        MasterProcess=18
      endif   
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      if( Unweighted ) NDim=NDim+1   ! variable to decide which partonic channel
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.1 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      if( TTBPhoton_SMonly ) then
        MasterProcess=9
      else
        MasterProcess=18
      endif 
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=9
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.5 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=9
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 3  ! additional gluons in the top decay
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.23 ) THEN !   3_Str  + 4_AStr --> 1_ATop + 2_Top + 5_Pho(in decay)
  IF( CORRECTION.LE.1 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 3    ! photon phase space
      NDim = NDim + 2    ! shat integration
      if( Unweighted ) NDim=NDim+1   ! variable to decide which nPhoRad
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.5 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 3    ! additional gluons in the top decay
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.24 ) THEN !   3_Str  + 5_Glu  --> 4_Str  + 1_ATop + 2_Top + 6_Pho(in production)
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,-1,3,-2,4/)
      MasterProcess=11
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 8    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=9
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.25 ) THEN  !   3_Str  + 5_Glu  --> 4_Str  + 1_ATop + 2_Top + 6_Pho(in decay)
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,3,-2/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 3    ! photon phase space
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 3    ! photon phase space
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.26 ) THEN !   4_AStr + 5_Glu  --> 3_AStr + 1_ATop + 2_Top + 6_Pho(in production)
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,3,-1,-2,4/)
      MasterProcess=11
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 8    ! t tbar glu photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=9
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.27 ) THEN !   4_AStr + 5_Glu  --> 3_AStr + 1_ATop + 2_Top + 6_Pho(in decay)
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,3,-1,-2/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 8    ! t tbar glu photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.28 ) THEN !   3_Glu  + 4_Glu  --> 5_Glu  + 1_ATop + 2_Top + 6_Pho(in production)
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,-1,-2,3,4/)
      MasterProcess=10
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 8    ! t tbar glu photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=8
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF


ELSEIF( PROCESS.EQ.29 ) THEN !   3_Glu  + 4_Glu  --> 5_Glu  + 1_ATop + 2_Top + 6_Pho(in decay)
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=3
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 8    ! t tbar glu photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=1
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar PS photon integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.30 ) THEN !   3_Str  + 4_AStr --> 5_Glu  + 1_ATop + 2_Top + 6_Pho(in production)
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,-1,-2,3,4/)
      MasterProcess=11
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 8    ! t tbar glu photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=9
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF


ELSEIF( PROCESS.EQ.31 ) THEN !   3_Str  + 4_AStr --> 5_Glu  + 1_ATop + 2_Top + 6_Pho(in decay)
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 8    ! t tbar glu photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF


ELSEIF( PROCESS.EQ.33 ) THEN !   3_Glu  + 4_Glu  --> 1_ATop + 2_Top + 5_Glu(in decay)
  IF( CORRECTION.LE.1 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=1
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 3    ! gluon phase space
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=1
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 3    ! gluon phase space
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.5 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=1
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar gluon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 3    ! additional gluon in the top decay
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.34 ) THEN !   3_Str  + 4_AStr --> 1_ATop + 2_Top + 5_Glu(in decay)
  IF( CORRECTION.LE.1 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 3    ! gluon phase space
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! t tbar gluon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.5 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! t tbar gluon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 3    ! additional gluon in the top decay
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF




ELSEIF( PROCESS.EQ.35 ) THEN  !   3_Str  + 5_Glu  --> 4_Str  + 1_ATop + 2_Top + 6_Glu(in decay)
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,3,-2/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 3    ! gluon phase space
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 3    ! gluon phase space
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF


ELSEIF( PROCESS.EQ.36 ) THEN !   4_AStr + 5_Glu  --> 3_AStr + 1_ATop + 2_Top + 6_Glu(in decay)
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,3,-1,-2/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 8    ! t tbar glu glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF




ELSEIF( PROCESS.EQ.37 ) THEN !   3_Glu  + 4_Glu  --> 5_Glu  + 1_ATop + 2_Top + 6_Glu(in decay)
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=3
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 8    ! t tbar glu glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=1
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar PS glu integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF




ELSEIF( PROCESS.EQ.38 ) THEN !   3_Str  + 4_AStr --> 5_Glu  + 1_ATop + 2_Top + Glu(in decay)
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 8    ! t tbar glu glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF




ELSEIF( PROCESS.EQ.41 ) THEN !   3_Glu  + 4_Glu  --> 1_AHeavyTop + 2_HeavyTop

 m_SMTop = m_Top
 m_Top = m_HTop!  permanently overwriting m_Top

  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=1
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! stop decays
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.1 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=31
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 4    ! T -> A0+t decays
      VegasNc0_default = 50000
      VegasNc1_default = 50000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=1
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 4    ! T -> A0+t decays
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.5 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=1
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 4    ! T -> A0+t decays
      NDim = NDim + 3+3  ! additional gluons in the top decay
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.42 ) THEN !   3_Str  + 4_AStr --> 1_AHeavyTop + 2_HeavyTop

 m_SMTop = m_Top
 m_Top = m_HTop!  permanently overwriting m_Top

  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! stop decays
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.1 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=32
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 4    ! T -> A0+t decays
      VegasNc0_default = 50000
      VegasNc1_default = 50000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 4    ! T -> A0+t decays
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.5 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 4    ! T -> A0+t decays
      NDim = NDim + 3+3  ! additional gluons in the top decay
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.43 ) THEN !   3_Str  + 4_Glu  --> 1_AHeavyTop + 2_HeavyTop + 5_Str

! temporarily reset m_Top for InitMasterprocess and InitProcess
 m_SMTop = m_Top
 m_Top = m_HTop
! will be restored in StartVegas

  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,3,-2/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 5    ! st stbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! Heavy top decays
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000

  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! HeavyTop decays
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.44 ) THEN !   3_Glu  + 4_AStr  --> 1_AHeavyTop + 2_HeavyTop + 5_AStr

! temporarily reset m_Top for InitMasterprocess and InitProcess
 m_SMTop = m_Top
 m_Top = m_HTop
! will be restored in StartVegas

  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,3,-1,-2/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 5    ! st stbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! Heavy top decays
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000

  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! Heavy top decays
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF





ELSEIF( PROCESS.EQ.45 ) THEN !   3_Glu  + 4_Glu  --> 1_AHeavyTop + 2_HeavyTop + 5_Glu(in production)

! temporarily reset m_Top for InitMasterprocess and InitProcess
 m_SMTop = m_Top
 m_Top = m_HTop
! will be restored in StartVegas

  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=3
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! st stbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! Heavy top decays
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000

  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=1
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! Heavy top decays
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.46 ) THEN !   3_Str  + 4_AStr  --> 1_AHeavyTop + 2_HeavyTop + 5_Glu(in production)

! temporarily reset m_Top for InitMasterprocess and InitProcess
 m_SMTop = m_Top
 m_Top = m_HTop
! will be restored in StartVegas

  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! st stbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! Heavy top decays
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000

  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! Heavy top decays
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF






ELSEIF( PROCESS.EQ.47 .OR. PROCESS.EQ.48 ) THEN !   A/HTop -> BH/Bar + A/Top (HTop width)

! temporarily reset m_Top for InitMasterprocess and InitProcess
 m_SMTop = m_Top
 m_Top = m_HTop
! will be restored in StartVegas

  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 3
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      IF( PROCESS.EQ.47 ) MasterProcess=43
      IF( PROCESS.EQ.48 ) MasterProcess=44
      NDim = NDim + 2    ! st PS integration
      NDim = NDim + 4    ! fake t PS integration
!       NDim = NDim + 1    ! for dummy integration
      VegasNc0_default = 200000
      VegasNc1_default = 200000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 3
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      IF( PROCESS.EQ.47 ) MasterProcess=43
      IF( PROCESS.EQ.48 ) MasterProcess=44
      NDim = NDim + 2    ! st PS integration
      NDim = NDim + 4    ! fake t PS integration
!       NDim = NDim + 1    ! for dummy integration
      VegasNc0_default = 200000
      VegasNc1_default = 200000
  ELSEIF( CORRECTION.EQ.5 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      IF( PROCESS.EQ.47 ) MasterProcess=43
      IF( PROCESS.EQ.48 ) MasterProcess=44
      NDim = NDim + 2    ! st PS integration
      NDim = NDim + 3    ! real gluon
      NDim = NDim + 4    ! fake t PS integration
      VegasNc0_default = 200000
      VegasNc1_default = 200000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF






ELSEIF( PROCESS.EQ.51 ) THEN !   3_Glu  + 4_Glu  --> 1_ASTop + 2_STop
  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=12
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! st stbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! stop decays
      VegasNc0_default = 200000
      VegasNc1_default = 200000
  ELSEIF( CORRECTION.EQ.1 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=12
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! st stbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! stop decays
      VegasNc0_default = 200000
      VegasNc1_default = 200000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=12
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! st stbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 4    ! stop decays
      VegasNc0_default = 200000
      VegasNc1_default = 200000
  ELSEIF( CORRECTION.EQ.5 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=12
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! st stbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 4    ! stop decays
      NDim = NDim + 3    ! real gluon
      VegasNc0_default = 200000
      VegasNc1_default = 200000

  ELSE
      call Error("Correction to this process is not available")
  ENDIF




ELSEIF( PROCESS.EQ.52 ) THEN !   3_Str  + 4_AStr  --> 1_ASTop + 2_STop
  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=13
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! st stbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! stop decays
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.1 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=13
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! st stbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! stop decays
      VegasNc0_default = 200000
      VegasNc1_default = 200000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=13
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! st stbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 4    ! stop decays
      VegasNc0_default = 200000
      VegasNc1_default = 200000
  ELSEIF( CORRECTION.EQ.5 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=13
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! st stbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 4    ! stop decays
      NDim = NDim + 3    ! real gluon
      VegasNc0_default = 200000
      VegasNc1_default = 200000

  ELSE
      call Error("Correction to this process is not available")
  ENDIF




ELSEIF( PROCESS.EQ.53 ) THEN !   3_Str  + 4_Glu  --> 1_ASTop + 2_STop + 5_Str
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,3,-2/)
      MasterProcess=15
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 5    ! st stbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! stop decays
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000

  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=13
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! stop decays
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.54 ) THEN !   3_Glu  + 4_AStr  --> 1_ASTop + 2_STop + 5_AStr
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,3,-1,-2/)
      MasterProcess=15
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 5    ! st stbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! stop decays
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000

  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=13
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! stop decays
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF





ELSEIF( PROCESS.EQ.55 ) THEN !   3_Glu  + 4_Glu  --> 1_ASTop + 2_STop + 5_Glu(in production)
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=14
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! st stbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! stop decays
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000

  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=12
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! stop decays
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.56 ) THEN !   3_Str  + 4_AStr  --> 1_ASTop + 2_STop + 5_Glu(in production)
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=15
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! st stbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! stop decays
      VegasNc0_default = 2000000
      VegasNc1_default = 2000000

  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=13
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! stop decays
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 10000000
      VegasNc1_default = 10000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF






ELSEIF( PROCESS.EQ.57 .OR. PROCESS.EQ.58 ) THEN !   A/Stop -> Chi/Bar + A/Top (stop width)
  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 3
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      IF( PROCESS.EQ.57 ) MasterProcess=41
      IF( PROCESS.EQ.58 ) MasterProcess=42
      NDim = 0
      NDim = NDim + 2    ! st PS integration
      NDim = NDim + 4    ! fake t PS integration
!       NDim = NDim + 1    ! for dummy integration
      VegasNc0_default = 200000
      VegasNc1_default = 200000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 3
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      IF( PROCESS.EQ.57 ) MasterProcess=41
      IF( PROCESS.EQ.58 ) MasterProcess=42
      NDim = 0
      NDim = NDim + 2    ! st PS integration
      NDim = NDim + 4    ! fake t PS integration
!       NDim = NDim + 1    ! for dummy integration
      VegasNc0_default = 200000
      VegasNc1_default = 200000
  ELSEIF( CORRECTION.EQ.5 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      IF( PROCESS.EQ.57 ) MasterProcess=41
      IF( PROCESS.EQ.58 ) MasterProcess=42
      NDim = 0
      NDim = NDim + 2    ! st PS integration
      NDim = NDim + 3    ! real gluon
      NDim = NDim + 4    ! fake t PS integration
      VegasNc0_default = 200000
      VegasNc1_default = 200000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF







ELSEIF( PROCESS.EQ.59 ) THEN !   test process
  IF( CORRECTION.LE.1 ) THEN
      NumExtParticles = 6
!       NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
!       Crossing(:) = (/3,4,-1,-2,5/)
      Crossing(:) = (/3,4,-1,-2,5,6/)
!       Crossing(:) = (/3,4,-1,-2,5/)
      MasterProcess=16
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 8    ! st stbar PS integration
!       NDim = NDim + 5    ! st stbar PS integration
      NDim = NDim + 2    ! shat integration
      IF( XTOPDECAYS.NE.0 ) NDim = NDim + 4    ! stop decays
      VegasNc0_default = 200000
      VegasNc1_default = 200000

  ELSE
      call Error("Correction to this process is not available")
  ENDIF


ELSEIF( PROCESS.EQ.62 ) THEN !   3_Str  + 4_AStr --> Zprime --> 1_ATop + 2_Top
  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=62
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 50000
      VegasNc1_default = 50000
  ELSEIF (CORRECTION.EQ.1) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=62
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDIM = NDim + 1    ! x integration
      VegasNc0_default = 50000
      VegasNc1_default = 50000
   ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=62
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 50000
      VegasNc1_default = 50000
   ELSEIF( CORRECTION.EQ.5 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=62
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 3    ! additional gluons in the top decay
      VegasNc0_default = 50000
      VegasNc1_default = 50000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF

ELSEIF( PROCESS.EQ.63 ) THEN !  3_Str  + 5_Glu  --> 4_Str  + 1_ATop + 2_Top
   IF (CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,3,-2/)
      MasterProcess=63
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! BW remapping initial or final
      VegasNc0_default = 50000
      VegasNc1_default = 50000
  ELSEIF (CORRECTION.EQ.3) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=62
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDIM = NDim + 1    ! x integration
      VegasNc0_default = 50000
      VegasNc1_default = 50000
   ELSE
      call Error("Correction to this process is not available")
   ENDIF

ELSEIF( PROCESS.EQ.64 ) THEN ! 4_AStr + 5_Glu  --> 3_AStr + 1_ATop + 2_Top
   IF (CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,3,-2,-1/)
      MasterProcess=63
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! BW remapping initial or final
      VegasNc0_default = 50000
      VegasNc1_default = 50000
  ELSEIF (CORRECTION.EQ.3) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=62
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDIM = NDim + 1    ! x integration
      VegasNc0_default = 50000
      VegasNc1_default = 50000
   ELSE
      call Error("Correction to this process is not available")
   ENDIF

ELSEIF( PROCESS.EQ.66 ) THEN !  3_Str  + 4_AStr --> Zprime --> 1_ATop + 2_Top + 5_Glu
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=63
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! BW remapping initial or final
      VegasNc0_default = 50000
      VegasNc1_default = 50000
  ELSEIF ( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=62
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDIM = NDim + 1    ! x integration
      VegasNc0_default = 50000
      VegasNc1_default = 50000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF

ELSEIF( PROCESS.EQ.65 ) THEN ! Zprime-gluon interference
  IF( CORRECTION.EQ.0 ) THEN
      call Error("No tree-level interference with Z'")
  ELSEIF (CORRECTION.EQ.1) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1; print *, 'to have same kinematics of ID for poles cancellation'
      VegasNc0_default = 50000
      VegasNc1_default = 50000
   ENDIF


ELSEIF( PROCESS.EQ.67 ) THEN !  3_Str  + 5_Glu  --> 4_Str  + 1_ATop + 2_Top, Zprime-gluon interference
   IF (CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,3,-2/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 50000
      VegasNc1_default = 50000
  ELSEIF (CORRECTION.EQ.3) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDIM = NDim + 1    ! x integration
      VegasNc0_default = 50000
      VegasNc1_default = 50000
   ELSE
      call Error("Correction to this process is not available")
   ENDIF

ELSEIF( PROCESS.EQ.68 ) THEN ! 4_AStr + 5_Glu  --> 3_AStr + 1_ATop + 2_Top
   IF (CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,3,-2,-1/)
      MasterProcess=4
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 50000
      VegasNc1_default = 50000
  ELSEIF (CORRECTION.EQ.3) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg*GluonColAvg
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDIM = NDim + 1    ! x integration
      VegasNc0_default = 50000
      VegasNc1_default = 50000
   ELSE
      call Error("Correction to this process is not available")
   ENDIF

 ELSEIF( PROCESS.EQ.69 ) THEN
    IF (CORRECTION.EQ.2 ) THEN
       NumExtParticles = 5
       allocate(Crossing(1:NumExtParticles))
       allocate(ExtParticle(1:NumExtParticles))
       Crossing(:) = (/4,5,-1,-2,3/)
       MasterProcess=4
       AvgFactor = SpinAvg * QuarkColAvg**2
       NDim = NDim + 5    ! t tbar glu PS integration
       NDim = NDim + 2    ! shat integration
       VegasNc0_default = 50000
       VegasNc1_default = 50000
    ELSEIF (CORRECTION.EQ.3) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=2
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDIM = NDim + 1    ! x integration
      VegasNc0_default = 50000
      VegasNc1_default = 50000
   ELSE
      call Error("Correction to this process is not available")
   ENDIF


ELSEIF( PROCESS.EQ.71 ) THEN !   3_Glu  + 4_Glu  --> 1_ATop + 2_Top + 5_Z ! ttbZ
  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=17
      NDim = NDim + 5    ! PS integration
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.1 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=17
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=17
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.5 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=17
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 3  ! additional gluons in the top decay
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF


ELSEIF( PROCESS.EQ.72 ) THEN !   3_Str  + 4_AStr --> 1_ATop + 2_Top + 5_Z ! ttbZ
  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=18
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    !  PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.1 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=18
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=18
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.5 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=18
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    !  PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 3  ! additional gluons in the top decay
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF






ELSEIF( PROCESS.EQ.73 ) THEN !   3_Str  + 5_Glu  --> 4_Str  + 1_ATop + 2_Top + 6_Z
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,-1,3,-2,4/)
      MasterProcess=20
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 8    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=18
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.74 ) THEN !   4_AStr + 5_Glu  --> 3_AStr + 1_ATop + 2_Top + 6_Z
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,3,-1,-2,4/)
      MasterProcess=20
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 8    ! t tbar glu photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=18
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF




ELSEIF( PROCESS.EQ.75 ) THEN !   3_Glu  + 4_Glu  --> 5_Glu  + 1_ATop + 2_Top + 6_Z
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,-1,-2,3,4/)
      MasterProcess=19
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 8    ! t tbar glu photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=17
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.76 ) THEN !   3_Str  + 4_AStr --> 5_Glu  + 1_ATop + 2_Top + 6_Z
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,-1,-2,3,4/)
      MasterProcess=20
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 8    ! t tbar glu photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=18
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF


! ELSEIF( PROCESS.EQ.81 ) THEN !   3_Glu  + 4_Glu  --> 1_ATop + 2_Top + 5_Pho ! ttbPhoton
!   IF( CORRECTION.EQ.0 ) THEN
!       NumExtParticles = 5
!       allocate(Crossing(1:NumExtParticles))
!       allocate(ExtParticle(1:NumExtParticles))
!       Crossing(:) = (/4,5,-1,-2,3/)
!       MasterProcess=17
!       NDim = NDim + 5    ! PS integration
!       AvgFactor = SpinAvg * GluonColAvg**2
!       NDim = NDim + 2    ! shat integration
!       VegasNc0_default = 100000
!       VegasNc1_default = 100000
!   ELSEIF( CORRECTION.EQ.1 ) THEN
!       NumExtParticles = 5
!       allocate(Crossing(1:NumExtParticles))
!       allocate(ExtParticle(1:NumExtParticles))
!       Crossing(:) = (/4,5,-1,-2,3/)
!       MasterProcess=17
!       AvgFactor = SpinAvg * GluonColAvg**2
!       NDim = NDim + 5    ! t tbar photon PS integration
!       NDim = NDim + 2    ! shat integration
!       VegasNc0_default = 100000
!       VegasNc1_default = 100000
!   ELSE
!       call Error("Correction to this process is not available")
!   ENDIF


! ELSEIF( PROCESS.EQ.82 ) THEN !   3_Glu  + 4_Glu  --> 1_ATop + 2_Top + 5_Pho ! ttbPhoton
!   IF( CORRECTION.EQ.0 ) THEN
!       NumExtParticles = 5
!       allocate(Crossing(1:NumExtParticles))
!       allocate(ExtParticle(1:NumExtParticles))
!       Crossing(:) = (/4,5,-1,-2,3/)
!       MasterProcess=18
!       NDim = NDim + 5    ! PS integration
!       AvgFactor = SpinAvg * QuarkColAvg**2
!       NDim = NDim + 2    ! shat integration
!       VegasNc0_default = 100000
!       VegasNc1_default = 100000
!   ELSEIF( CORRECTION.EQ.1 ) THEN
!       NumExtParticles = 5
!       allocate(Crossing(1:NumExtParticles))
!       allocate(ExtParticle(1:NumExtParticles))
!       Crossing(:) = (/4,5,-1,-2,3/)
!       MasterProcess=18
!       AvgFactor = SpinAvg * QuarkColAvg**2
!       NDim = NDim + 5    ! t tbar photon PS integration
!       NDim = NDim + 2    ! shat integration
!       VegasNc0_default = 100000
!       VegasNc1_default = 100000
!   ELSE
!       call Error("Correction to this process is not available")
!   ENDIF


! ELSEIF( PROCESS.EQ.86 ) THEN !   3_Str  + 4_AStr --> 5_Glu  + 1_ATop + 2_Top + 6_Pho
!   IF( CORRECTION.EQ.2 ) THEN
!       NumExtParticles = 6
!       allocate(Crossing(1:NumExtParticles))
!       allocate(ExtParticle(1:NumExtParticles))
!       Crossing(:) = (/5,6,-1,-2,3,4/)
!       MasterProcess=20
!       AvgFactor = SpinAvg * QuarkColAvg**2
!       NDim = NDim + 8    ! t tbar glu photon PS integration
!       NDim = NDim + 2    ! shat integration
!       VegasNc0_default = 1000000
!       VegasNc1_default = 1000000
!   ELSEIF( CORRECTION.EQ.3 ) THEN
!       NumExtParticles = 5
!       allocate(Crossing(1:NumExtParticles))
!       allocate(ExtParticle(1:NumExtParticles))
!       Crossing(:) = (/4,5,-1,-2,3/)
!       MasterProcess=18
!       AvgFactor = SpinAvg * QuarkColAvg**2
!       NDim = NDim + 5    ! t tbar photon PS integration
!       NDim = NDim + 2    ! shat integration
!       NDim = NDim + 1    ! x integration
!       VegasNc0_default = 100000
!       VegasNc1_default = 100000
!   ELSE
!       call Error("Correction to this process is not available")
!   ENDIF


ELSEIF( PROCESS.EQ.91 ) THEN !   3_e-  + 4_e+ --> 1_ATop + 2_Top
  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=21
      AvgFactor = SpinAvg
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 500000
      VegasNc1_default = 500000
  ELSEIF( CORRECTION.EQ.1 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=21
      AvgFactor = SpinAvg
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 200000
      VegasNc1_default = 200000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=21
      AvgFactor = SpinAvg
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 200000
      VegasNc1_default = 200000
  ELSEIF( CORRECTION.EQ.5 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=21
      AvgFactor = SpinAvg
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 3+3  ! additional gluons in the top decay
      VegasNc0_default = 200000
      VegasNc1_default = 200000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF

  
  
ELSEIF( PROCESS.EQ.92 ) THEN !   3_e-  + 4_e+ --> 5_Glu  + 1_ATop + 2_Top
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=22
      AvgFactor = SpinAvg
      NDim = NDim + 5    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 400000
      VegasNc1_default = 400000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 4
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/3,4,-1,-2/)
      MasterProcess=21
      AvgFactor = SpinAvg
      NDim = NDim + 2    ! t tbar PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 200000
      VegasNc1_default = 200000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF




  
ELSEIF( PROCESS.EQ.101 ) THEN !   3_Glu  + 4_Glu  --> 1_ATop + 2_Top + 5_Hi
  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=23
      NDim = NDim + 5    ! PS integration
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.1 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=23
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=23
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.5 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=23
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 3  ! additional gluons in the top decay
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF


ELSEIF( PROCESS.EQ.102 ) THEN !   3_Str  + 4_AStr --> 1_ATop + 2_Top + 5_Hi
  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=24
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    !  PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.1 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=24
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSEIF( CORRECTION.EQ.4 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=24
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.5 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=24
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    !  PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 3  ! additional gluons in the top decay
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF






ELSEIF( PROCESS.EQ.103 ) THEN !   3_Str  + 5_Glu  --> 4_Str  + 1_ATop + 2_Top + 6_Hi
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,-1,3,-2,4/)
      MasterProcess=26
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 8    ! t tbar glu PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=24
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.104 ) THEN !   4_AStr + 5_Glu  --> 3_AStr + 1_ATop + 2_Top + 6_Hi
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,3,-1,-2,4/)
      MasterProcess=26
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 8    ! t tbar glu photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=24
      AvgFactor = SpinAvg * QuarkColAvg * GluonColAvg
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF




ELSEIF( PROCESS.EQ.105 ) THEN !   3_Glu  + 4_Glu  --> 5_Glu  + 1_ATop + 2_Top + 6_Hi
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,-1,-2,3,4/)
      MasterProcess=25
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 8    ! t tbar glu photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=23
      AvgFactor = SpinAvg * GluonColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF



ELSEIF( PROCESS.EQ.106 ) THEN !   3_Str  + 4_AStr --> 5_Glu  + 1_ATop + 2_Top + 6_Hi
  IF( CORRECTION.EQ.2 ) THEN
      NumExtParticles = 6
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/5,6,-1,-2,3,4/)
      MasterProcess=26
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 8    ! t tbar glu photon PS integration
      NDim = NDim + 2    ! shat integration
      VegasNc0_default = 1000000
      VegasNc1_default = 1000000
  ELSEIF( CORRECTION.EQ.3 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=24
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 5    ! t tbar photon PS integration
      NDim = NDim + 2    ! shat integration
      NDim = NDim + 1    ! x integration
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF
  

!! RR added for single top + H -- LO only
ELSEIF( PROCESS.EQ.111 ) THEN !   3_Up  + 4_Bot  --> 1_Top + 5_Hig + 2_Dn                                                                                            
  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=73
      NDim = NDim + 5    ! PS integration                                                                                                                                  
      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! shat integration                                                                                                                                 
      VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF
  

ELSEIF( PROCESS.EQ.112 ) THEN !   3_Up  + 4_ABot  --> 1_ATop + 5_Hig + 2_Dn                                                                                                       
  IF( CORRECTION.EQ.0 ) THEN
      NumExtParticles = 5
      allocate(Crossing(1:NumExtParticles))
      allocate(ExtParticle(1:NumExtParticles))
      Crossing(:) = (/4,5,-1,-2,3/)
      MasterProcess=74
      NDim = NDim + 5    ! PS integration

      AvgFactor = SpinAvg * QuarkColAvg**2
      NDim = NDim + 2    ! shat integration                                                                                                                                
 
     VegasNc0_default = 100000
      VegasNc1_default = 100000
  ELSE
      call Error("Correction to this process is not available")
  ENDIF


ELSEIF( Unweighted .and. Process.gt.01000000 ) then 
  RETURN
  
ELSE
    call Error("Process not available")
ENDIF

  call InitMasterProcess()

END SUBROUTINE








SUBROUTINE InitMasterProcess()
use ModParameters
use ModMisc
implicit none
integer :: NPart,sig_tb,sig_t,NAmp

! print *, ""
! print *, "Initializing Process   ", Process
! print *, "             Master    ", MasterProcess
! print *, "             Correction", Correction


IF( MASTERPROCESS.EQ.0 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = Glu_
    ExtParticle(4)%PartType = Glu_
    ExtParticle(5)%PartType = Glu_
    ExtParticle(6)%PartType = Glu_
    ExtParticle(7)%PartType = Glu_
    NumPrimAmps = 1
    NumBornAmps = 1
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo
    NumHelicities = 1
    allocate(Helicities(1:NumHelicities,1:NumExtParticles))
    Helicities(1,1:NumExtParticles) = (/+1,+1,-1,-1,-1,-1,+1/)


ELSEIF( MASTERPROCESS.EQ.1 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = Glu_
    ExtParticle(4)%PartType = Glu_
    IF( Correction.EQ.0 .OR. Correction.GE.4 ) THEN
      NumPrimAmps = 2
      NumBornAmps = 2
    ELSEIF( Correction.EQ.1 ) THEN
      NumPrimAmps = 10
      NumBornAmps = 2
    ELSEIF( Correction.EQ.3 ) THEN
      NumPrimAmps = 0
      NumBornAmps = 0
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( TOPDECAYS.GE.1 .OR. XTOPDECAYS.GE.1 .OR. XTOPDECAYS.GE.2 ) THEN
              NumHelicities = 4
              allocate(Helicities(1:NumHelicities,1:NumExtParticles))
              Helicities(1,1:4) = (/0,0,+1,+1/)
              Helicities(2,1:4) = (/0,0,+1,-1/)
              Helicities(3,1:4) = (/0,0,-1,+1/)
              Helicities(4,1:4) = (/0,0,-1,-1/)
    ELSE
              NumHelicities = 8
              allocate(Helicities(1:NumHelicities,1:NumExtParticles))
              sig_tb=+1; sig_t =+1;
              Helicities(1,1:NumExtParticles) = (/sig_tb,sig_t,+1,+1/)
              Helicities(2,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
              sig_tb=+1; sig_t =-1;
              Helicities(3,1:NumExtParticles) = (/sig_tb,sig_t,+1,+1/)
              Helicities(4,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
              sig_tb=-1; sig_t =+1;
              Helicities(5,1:NumExtParticles) = (/sig_tb,sig_t,+1,+1/)
              Helicities(6,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
              sig_tb=-1; sig_t =-1;
              Helicities(7,1:NumExtParticles) = (/sig_tb,sig_t,+1,+1/)
              Helicities(8,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
    !  additional helicities when parity inversion is not applied:    changes affect also EvalCS_ttb_NLODK_noSC
    !         sig_tb=+1; sig_t =+1;
    !         Helicities(9 ,1:NumExtParticles) = (/sig_tb,sig_t,-1,-1/)
    !         Helicities(10,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
    !         sig_tb=+1; sig_t =-1;
    !         Helicities(11,1:NumExtParticles) = (/sig_tb,sig_t,-1,-1/)
    !         Helicities(12,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
    !         sig_tb=-1; sig_t =+1;
    !         Helicities(13,1:NumExtParticles) = (/sig_tb,sig_t,-1,-1/)
    !         Helicities(14,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
    !         sig_tb=-1; sig_t =-1;
    !         Helicities(15,1:NumExtParticles) = (/sig_tb,sig_t,-1,-1/)
    !         Helicities(16,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
    ENDIF



ELSEIF( MASTERPROCESS.EQ.2 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = AStr_
    ExtParticle(4)%PartType = Str_
    IF( Correction.EQ.0 .OR. Correction.GE.4 ) THEN
      NumPrimAmps = 1
      NumBornAmps = 1
    ELSEIF( Correction.EQ.1 ) THEN
      NumPrimAmps = 6
      NumBornAmps = 1
    ELSEIF( Correction.EQ.3 ) THEN
      NumPrimAmps = 0
      NumBornAmps = 0
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( TOPDECAYS.GE.1 .OR. XTOPDECAYS.GE.1 .OR. XTOPDECAYS.GE.2 ) THEN
              NumHelicities = 4
              allocate(Helicities(1:NumHelicities,1:NumExtParticles))
              Helicities(1,1:4) = (/0,0,+1,+1/)
              Helicities(2,1:4) = (/0,0,+1,-1/)
              Helicities(3,1:4) = (/0,0,-1,+1/)
              Helicities(4,1:4) = (/0,0,-1,-1/)
    ELSE
      NumHelicities = 4
      allocate(Helicities(1:NumHelicities,1:NumExtParticles))
      sig_tb=+1; sig_t =+1;
  !    Helicities(1,1:NumExtParticles) = (/sig_tb,sig_t,+1,+1/)  ! the x,x,+1,+1 helicities lead to vanishing tree contribution
      Helicities(1,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
      sig_tb=+1; sig_t =-1;
  !    Helicities(3,1:NumExtParticles) = (/sig_tb,sig_t,+1,+1/)
      Helicities(2,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
      sig_tb=-1; sig_t =+1;
  !    Helicities(5,1:NumExtParticles) = (/sig_tb,sig_t,+1,+1/)
      Helicities(3,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
      sig_tb=-1; sig_t =-1;
  !    Helicities(7,1:NumExtParticles) = (/sig_tb,sig_t,+1,+1/)
      Helicities(4,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
  !   additional helicities when parity inversion is not applied: changes affect also EvalCS_ttb_NLODK_noSC
  !     sig_tb=+1; sig_t =+1;
  !     Helicities(9 ,1:NumExtParticles) = (/sig_tb,sig_t,-1,-1/)
  !     Helicities(10,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
  !     sig_tb=+1; sig_t =-1;
  !     Helicities(11,1:NumExtParticles) = (/sig_tb,sig_t,-1,-1/)
  !     Helicities(12,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
  !     sig_tb=-1; sig_t =+1;
  !     Helicities(13,1:NumExtParticles) = (/sig_tb,sig_t,-1,-1/)
  !     Helicities(14,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
  !     sig_tb=-1; sig_t =-1;
  !     Helicities(15,1:NumExtParticles) = (/sig_tb,sig_t,-1,-1/)
  !     Helicities(16,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
    ENDIF



ELSEIF( MASTERPROCESS.EQ.3 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = Glu_
    ExtParticle(4)%PartType = Glu_
    ExtParticle(5)%PartType = Glu_

    IF( Correction.EQ.0 .OR.  Correction.EQ.2 .OR.  Correction.EQ.4 ) THEN
      NumPrimAmps = 6
      NumBornAmps = 6
    ELSEIF( Correction.EQ.1 ) THEN
      NumPrimAmps = 48
      NumBornAmps = 6
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( TOPDECAYS.GE.1 .OR. XTOPDECAYS.GE.1 .OR. XTOPDECAYS.GE.2 ) THEN
        NumHelicities = 8
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))
        Helicities(1,1:5) = (/0,0,+1,+1,+1/)
        Helicities(2,1:5) = (/0,0,+1,+1,-1/)
        Helicities(3,1:5) = (/0,0,+1,-1,+1/)
        Helicities(4,1:5) = (/0,0,+1,-1,-1/)
        Helicities(5,1:5) = (/0,0,-1,+1,+1/)
        Helicities(6,1:5) = (/0,0,-1,+1,-1/)
        Helicities(7,1:5) = (/0,0,-1,-1,+1/)
        Helicities(8,1:5) = (/0,0,-1,-1,-1/)
    ELSE
        NumHelicities = 32
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))
        sig_tb=+1; sig_t =+1;
        Helicities( 1,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
        Helicities( 2,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
        Helicities( 3,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
        Helicities( 4,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
        sig_tb=+1; sig_t =-1;
        Helicities( 5,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
        Helicities( 6,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
        Helicities( 7,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
        Helicities( 8,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
        sig_tb=-1; sig_t =+1;
        Helicities( 9,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
        Helicities(10,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
        Helicities(11,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
        Helicities(12,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
        sig_tb=-1; sig_t =-1;
        Helicities(13,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
        Helicities(14,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
        Helicities(15,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
        Helicities(16,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
    !   additional helicities when parity inversion is not applied:
        sig_tb=-1; sig_t =-1;
        Helicities(17,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
        Helicities(18,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
        Helicities(19,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
        Helicities(20,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
        sig_tb=-1; sig_t =+1;
        Helicities(21,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
        Helicities(22,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
        Helicities(23,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
        Helicities(24,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
        sig_tb=+1; sig_t =-1;
        Helicities(25,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
        Helicities(26,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
        Helicities(27,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
        Helicities(28,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
        sig_tb=+1; sig_t =+1;
        Helicities(29,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
        Helicities(30,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
        Helicities(31,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
        Helicities(32,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
    ENDIF



ELSEIF( MASTERPROCESS.EQ.4 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = AStr_
    ExtParticle(4)%PartType = Str_
    ExtParticle(5)%PartType = Glu_

    IF( Correction.EQ.0 .OR.  Correction.EQ.2 .OR.  Correction.EQ.4 ) THEN
      NumPrimAmps = 4
      NumBornAmps = 4
    ELSEIF( Correction.EQ.1 ) THEN
      NumPrimAmps = 24
      NumBornAmps = 4
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( TOPDECAYS.GE.1 .OR. XTOPDECAYS.GE.1 .OR. XTOPDECAYS.GE.2 ) THEN
        NumHelicities = 8
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))
        Helicities(1,1:5) = (/0,0,+1,+1,+1/)
        Helicities(2,1:5) = (/0,0,+1,+1,-1/)
        Helicities(3,1:5) = (/0,0,+1,-1,+1/)
        Helicities(4,1:5) = (/0,0,+1,-1,-1/)
        Helicities(5,1:5) = (/0,0,-1,+1,+1/)
        Helicities(6,1:5) = (/0,0,-1,+1,-1/)
        Helicities(7,1:5) = (/0,0,-1,-1,+1/)
        Helicities(8,1:5) = (/0,0,-1,-1,-1/)
    !    print *, "remove vanishing helicities!"
    !    stop

    ELSE
!     NumHelicities = 16
    NumHelicities = 32
    allocate(Helicities(1:NumHelicities,1:NumExtParticles))
!     sig_tb=+1; sig_t =+1;         ! works for qqb initial state but not for qg and qbg because ++/-- helicities don't vanish
! !    Helicities( 1,1:5) = (/sig_tb,sig_t,+1,+1,+1/)!
! !    Helicities( 2,1:5) = (/sig_tb,sig_t,+1,+1,-1/)!
!     Helicities( 1,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
!     Helicities( 2,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
!     sig_tb=+1; sig_t =-1;
! !    Helicities( 5,1:5) = (/sig_tb,sig_t,+1,+1,+1/)!
! !    Helicities( 6,1:5) = (/sig_tb,sig_t,+1,+1,-1/)!
!     Helicities( 3,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
!     Helicities( 4,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
!     sig_tb=-1; sig_t =+1;
! !    Helicities( 9,1:5) = (/sig_tb,sig_t,+1,+1,+1/)!
! !    Helicities(10,1:5) = (/sig_tb,sig_t,+1,+1,-1/)!
!     Helicities(5,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
!     Helicities(6,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
!     sig_tb=-1; sig_t =-1;
! !    Helicities(13,1:5) = (/sig_tb,sig_t,+1,+1,+1/)!
! !    Helicities(14,1:5) = (/sig_tb,sig_t,+1,+1,-1/)!
!     Helicities(7,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
!     Helicities(8,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
! ! !   additional helicities when parity inversion is not applied:
!       sig_tb=-1; sig_t =-1;
! !      Helicities(17,1:5) = (/sig_tb,sig_t,-1,-1,-1/)!
! !      Helicities(18,1:5) = (/sig_tb,sig_t,-1,-1,+1/)!
!       Helicities(9,1:5)  = (/sig_tb,sig_t,-1,+1,+1/)
!       Helicities(10,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
!       sig_tb=-1; sig_t =+1;
! !      Helicities(21,1:5) = (/sig_tb,sig_t,-1,-1,-1/)!
! !      Helicities(22,1:5) = (/sig_tb,sig_t,-1,-1,+1/)!
!       Helicities(11,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
!       Helicities(12,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
!       sig_tb=+1; sig_t =-1;
! !      Helicities(25,1:5) = (/sig_tb,sig_t,-1,-1,-1/)!
! !      Helicities(26,1:5) = (/sig_tb,sig_t,-1,-1,+1/)!
!       Helicities(13,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
!       Helicities(14,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
!       sig_tb=+1; sig_t =+1;
! !      Helicities(29,1:5) = (/sig_tb,sig_t,-1,-1,-1/)!
! !      Helicities(30,1:5) = (/sig_tb,sig_t,-1,-1,+1/)!
!       Helicities(15,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
!       Helicities(16,1:5) = (/sig_tb,sig_t,-1,+1,-1/)



    sig_tb=+1; sig_t =+1;
    Helicities( 1,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
    Helicities( 2,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
    sig_tb=+1; sig_t =-1;
    Helicities( 3,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
    Helicities( 4,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
    sig_tb=-1; sig_t =+1;
    Helicities( 5,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
    Helicities( 6,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
    sig_tb=-1; sig_t =-1;
    Helicities( 7,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
    Helicities( 8,1:5) = (/sig_tb,sig_t,+1,-1,+1/)

    sig_tb=-1; sig_t =-1;
    Helicities( 9,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
    Helicities(10,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
    sig_tb=-1; sig_t =+1;
    Helicities(11,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
    Helicities(12,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
    sig_tb=+1; sig_t =-1;
    Helicities(13,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
    Helicities(14,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
    sig_tb=+1; sig_t =+1;
    Helicities(15,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
    Helicities(16,1:5) = (/sig_tb,sig_t,-1,+1,-1/)

!   these helicities don't contribute for qqb:
    if( PROCESS.EQ.6 ) NumHelicities = 16

    sig_tb=+1; sig_t =+1;
    Helicities(17,1:5) = (/sig_tb,sig_t,+1,+1,+1/)!
    Helicities(18,1:5) = (/sig_tb,sig_t,+1,+1,-1/)!
    sig_tb=+1; sig_t =-1;
    Helicities(19,1:5) = (/sig_tb,sig_t,+1,+1,+1/)!
    Helicities(20,1:5) = (/sig_tb,sig_t,+1,+1,-1/)!
    sig_tb=-1; sig_t =+1;
    Helicities(21,1:5) = (/sig_tb,sig_t,+1,+1,+1/)!
    Helicities(22,1:5) = (/sig_tb,sig_t,+1,+1,-1/)!
    sig_tb=-1; sig_t =-1;
    Helicities(23,1:5) = (/sig_tb,sig_t,+1,+1,+1/)!
    Helicities(24,1:5) = (/sig_tb,sig_t,+1,+1,-1/)!

    sig_tb=-1; sig_t =-1;
    Helicities(25,1:5) = (/sig_tb,sig_t,-1,-1,-1/)!
    Helicities(26,1:5) = (/sig_tb,sig_t,-1,-1,+1/)!
    sig_tb=-1; sig_t =+1;
    Helicities(27,1:5) = (/sig_tb,sig_t,-1,-1,-1/)!
    Helicities(28,1:5) = (/sig_tb,sig_t,-1,-1,+1/)!
    sig_tb=+1; sig_t =-1;
    Helicities(29,1:5) = (/sig_tb,sig_t,-1,-1,-1/)!
    Helicities(30,1:5) = (/sig_tb,sig_t,-1,-1,+1/)!
    sig_tb=+1; sig_t =+1;
    Helicities(31,1:5) = (/sig_tb,sig_t,-1,-1,-1/)!
    Helicities(32,1:5) = (/sig_tb,sig_t,-1,-1,+1/)!

    ENDIF


ELSEIF( MASTERPROCESS.EQ.5 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = Glu_
    ExtParticle(4)%PartType = Glu_
    ExtParticle(5)%PartType = Glu_
    ExtParticle(6)%PartType = Glu_

    IF( Correction.EQ.2 ) THEN
      NumPrimAmps = 24
      NumBornAmps = 24
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( TOPDECAYS.GE.1 ) THEN
    NumHelicities = 16
    allocate(Helicities(1:NumHelicities,1:NumExtParticles))
      ih=1
      do h3=-1,1,2
      do h4=-1,1,2
      do h5=-1,1,2
      do h6=-1,1,2
          if( ih.ge.17 ) cycle
          Helicities(ih,1:6) = (/0,0,h3,h4,h5,h6/)
          ih=ih+1
      enddo
      enddo
      enddo
      enddo
    ELSEIF( TOPDECAYS.EQ.0 ) then
        NumHelicities = 32  ! uses the parity flip
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))
          ih=1
          do h1=-1,1,2
          do h2=-1,1,2
          do h3=-1,1,2
          do h4=-1,1,2
          do h5=-1,1,2
          do h6=-1,1,2
              if( ih.ge.33 ) cycle
              Helicities(ih,1:6) = (/h1,h2,h3,h4,h5,h6/)
              ih=ih+1
          enddo
          enddo
          enddo
          enddo
          enddo
          enddo
    ENDIF


ELSEIF( MASTERPROCESS.EQ.6 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = AStr_
    ExtParticle(4)%PartType = Str_
    ExtParticle(5)%PartType = Glu_
    ExtParticle(6)%PartType = Glu_

    IF( Correction.EQ.2 ) THEN
       NumPrimAmps = 12
       NumBornAmps = 12
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( TOPDECAYS.GE.1 ) THEN
    NumHelicities = 16
    allocate(Helicities(1:NumHelicities,1:NumExtParticles))
      ih=1
      do h3=-1,1,2
      do h4=-1,1,2
      do h5=-1,1,2
      do h6=-1,1,2
          if( ih.ge.17 ) cycle
          Helicities(ih,1:6) = (/0,0,h3,h4,h5,h6/)
          ih=ih+1
      enddo
      enddo
      enddo
      enddo
    ELSEIF( TOPDECAYS.EQ.0 ) then
    NumHelicities = 64
    allocate(Helicities(1:NumHelicities,1:NumExtParticles))
      ih=1
      do h1=-1,1,2
      do h2=-1,1,2
      do h3=-1,1,2
      do h4=-1,1,2
      do h5=-1,1,2
      do h6=-1,1,2
          if( ih.ge.65 ) cycle
          Helicities(ih,1:6) = (/h1,h2,h3,h4,h5,h6/)
          ih=ih+1
      enddo
      enddo
      enddo
      enddo
      enddo
      enddo
    ENDIF

ELSEIF( MASTERPROCESS.EQ.7 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = AStr_
    ExtParticle(4)%PartType = Str_
    ExtParticle(5)%PartType = AChm_
    ExtParticle(6)%PartType = Chm_


ELSEIF( MASTERPROCESS.EQ.8 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = Glu_
    ExtParticle(4)%PartType = Glu_
    ExtParticle(5)%PartType = Glu_  ! this is the photon!

    IF( Correction.EQ.0 .OR. Correction.EQ.4 .OR.Correction.EQ.5 ) THEN
      NumPrimAmps = 2
      NumBornAmps = 2
    ELSEIF( Correction.EQ.1 ) THEN
      NumPrimAmps = 28
      NumBornAmps = 2
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( TOPDECAYS.GE.1 ) THEN
        NumHelicities = 8
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))
        Helicities(1,1:5) = (/0,0,+1,+1,+1/)
        Helicities(2,1:5) = (/0,0,+1,+1,-1/)
        Helicities(3,1:5) = (/0,0,+1,-1,+1/)
        Helicities(4,1:5) = (/0,0,+1,-1,-1/)
        Helicities(5,1:5) = (/0,0,-1,+1,+1/)
        Helicities(6,1:5) = (/0,0,-1,+1,-1/)
        Helicities(7,1:5) = (/0,0,-1,-1,+1/)
        Helicities(8,1:5) = (/0,0,-1,-1,-1/)
    ELSE
        NumHelicities = 32
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))
        sig_tb=+1; sig_t =+1;
        Helicities( 1,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
        Helicities( 2,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
        Helicities( 3,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
        Helicities( 4,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
        sig_tb=+1; sig_t =-1;
        Helicities( 5,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
        Helicities( 6,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
        Helicities( 7,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
        Helicities( 8,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
        sig_tb=-1; sig_t =+1;
        Helicities( 9,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
        Helicities(10,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
        Helicities(11,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
        Helicities(12,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
        sig_tb=-1; sig_t =-1;
        Helicities(13,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
        Helicities(14,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
        Helicities(15,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
        Helicities(16,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
    !   additional helicities when parity inversion is not applied:
        sig_tb=-1; sig_t =-1;
        Helicities(17,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
        Helicities(18,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
        Helicities(19,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
        Helicities(20,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
        sig_tb=-1; sig_t =+1;
        Helicities(21,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
        Helicities(22,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
        Helicities(23,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
        Helicities(24,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
        sig_tb=+1; sig_t =-1;
        Helicities(25,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
        Helicities(26,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
        Helicities(27,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
        Helicities(28,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
        sig_tb=+1; sig_t =+1;
        Helicities(29,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
        Helicities(30,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
        Helicities(31,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
        Helicities(32,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
    ENDIF


ELSEIF( MASTERPROCESS.EQ.9 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = AStr_
    ExtParticle(4)%PartType = Str_
    ExtParticle(5)%PartType = Glu_  ! this is the photon!

    IF( Correction.EQ.0 .OR. Correction.EQ.4 .OR.Correction.EQ.5) THEN
      NumPrimAmps = 2
      NumBornAmps = 2
    ELSEIF( Correction.EQ.1 ) THEN
      NumPrimAmps = 14
      NumBornAmps = 2
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( TOPDECAYS.GE.1 ) THEN
        NumHelicities = 8
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))
        Helicities(1,1:5) = (/0,0,+1,+1,+1/)
        Helicities(2,1:5) = (/0,0,+1,+1,-1/)
        Helicities(3,1:5) = (/0,0,+1,-1,+1/)
        Helicities(4,1:5) = (/0,0,+1,-1,-1/)
        Helicities(5,1:5) = (/0,0,-1,+1,+1/)
        Helicities(6,1:5) = (/0,0,-1,+1,-1/)
        Helicities(7,1:5) = (/0,0,-1,-1,+1/)
        Helicities(8,1:5) = (/0,0,-1,-1,-1/)
    ELSE
        NumHelicities = 32
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))
        sig_tb=+1; sig_t =+1;
        Helicities( 1,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
        Helicities( 2,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
        Helicities( 3,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
        Helicities( 4,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
        sig_tb=+1; sig_t =-1;
        Helicities( 5,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
        Helicities( 6,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
        Helicities( 7,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
        Helicities( 8,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
        sig_tb=-1; sig_t =+1;
        Helicities( 9,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
        Helicities(10,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
        Helicities(11,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
        Helicities(12,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
        sig_tb=-1; sig_t =-1;
        Helicities(13,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
        Helicities(14,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
        Helicities(15,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
        Helicities(16,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
    !   additional helicities when parity inversion is not applied:
        sig_tb=-1; sig_t =-1;
        Helicities(17,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
        Helicities(18,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
        Helicities(19,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
        Helicities(20,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
        sig_tb=-1; sig_t =+1;
        Helicities(21,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
        Helicities(22,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
        Helicities(23,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
        Helicities(24,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
        sig_tb=+1; sig_t =-1;
        Helicities(25,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
        Helicities(26,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
        Helicities(27,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
        Helicities(28,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
        sig_tb=+1; sig_t =+1;
        Helicities(29,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
        Helicities(30,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
        Helicities(31,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
        Helicities(32,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
    ENDIF




ELSEIF( MASTERPROCESS.EQ.10 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = Glu_
    ExtParticle(4)%PartType = Glu_
    ExtParticle(5)%PartType = Glu_
    ExtParticle(6)%PartType = Glu_  ! this is the photon!

    IF( Correction.EQ.2 ) THEN
      NumPrimAmps = 6
      NumBornAmps = 6
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo



    IF( TOPDECAYS.GE.1 ) THEN
    NumHelicities = 16
    allocate(Helicities(1:NumHelicities,1:NumExtParticles))
      ih=1
      do h3=-1,1,2
      do h4=-1,1,2
      do h5=-1,1,2
      do h6=-1,1,2
          if( ih.ge.17 ) cycle
          Helicities(ih,1:6) = (/0,0,h3,h4,h5,h6/)
          ih=ih+1
      enddo
      enddo
      enddo
      enddo
    ELSEIF( TOPDECAYS.EQ.0 ) then
    NumHelicities = 64
    allocate(Helicities(1:NumHelicities,1:NumExtParticles))
      ih=1
      do h1=-1,1,2
      do h2=-1,1,2
      do h3=-1,1,2
      do h4=-1,1,2
      do h5=-1,1,2
      do h6=-1,1,2
          if( ih.ge.65 ) cycle
          Helicities(ih,1:6) = (/h1,h2,h3,h4,h5,h6/)
          ih=ih+1
      enddo
      enddo
      enddo
      enddo
      enddo
      enddo
    ENDIF






ELSEIF( MASTERPROCESS.EQ.11 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = AChm_
    ExtParticle(4)%PartType = Chm_
    ExtParticle(5)%PartType = Glu_
    ExtParticle(6)%PartType = Glu_  ! this is the photon!

    IF( Correction.EQ.2 ) THEN
      NumPrimAmps = 10
      NumBornAmps = 10
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( TOPDECAYS.GE.1 ) THEN
    NumHelicities = 16
    allocate(Helicities(1:NumHelicities,1:NumExtParticles))
      ih=1
      do h3=-1,1,2
      do h4=-1,1,2
      do h5=-1,1,2
      do h6=-1,1,2
          if( ih.ge.17 ) cycle
          Helicities(ih,1:6) = (/0,0,h3,h4,h5,h6/)
          ih=ih+1
      enddo
      enddo
      enddo
      enddo
    ELSEIF( TOPDECAYS.EQ.0 ) then
    NumHelicities = 64
    allocate(Helicities(1:NumHelicities,1:NumExtParticles))
      ih=1
      do h1=-1,1,2
      do h2=-1,1,2
      do h3=-1,1,2
      do h4=-1,1,2
      do h5=-1,1,2
      do h6=-1,1,2
          if( ih.ge.65 ) cycle
          Helicities(ih,1:6) = (/h1,h2,h3,h4,h5,h6/)
          ih=ih+1
      enddo
      enddo
      enddo
      enddo
      enddo
      enddo
    ENDIF





ELSEIF( MASTERPROCESS.EQ.12 ) THEN

    ExtParticle(1)%PartType = ASTop_
    ExtParticle(2)%PartType = STop_
    ExtParticle(3)%PartType = Glu_
    ExtParticle(4)%PartType = Glu_
    IF( Correction.EQ.0 ) THEN
      NumPrimAmps = 2
      NumBornAmps = 2
!       NumPrimAmps = 4  ; print *, "for crossed check"
!       NumBornAmps = 4  ; print *, "for crossed check"

    ELSEIF( Correction.EQ.1 ) THEN
      NumPrimAmps = 12
      NumBornAmps = 2
    ELSEIF( Correction.EQ.3 ) THEN
    ELSEIF( Correction.EQ.4 ) THEN
      NumPrimAmps = 2
      NumBornAmps = 2
    ELSEIF( Correction.EQ.5 ) THEN
      NumPrimAmps = 2
      NumBornAmps = 2
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( XTOPDECAYS.EQ.0 ) THEN
       NumHelicities = 4
       allocate(Helicities(1:NumHelicities,1:6))
       Helicities(1,1:4) = (/0,0,+1,+1/)
       Helicities(2,1:4) = (/0,0,+1,-1/)
       Helicities(3,1:4) = (/0,0,-1,+1/)
       Helicities(4,1:4) = (/0,0,-1,-1/)
    ELSEIF( XTOPDECAYS.EQ.3 ) THEN   
       NumHelicities = 16
       allocate(Helicities(1:NumHelicities,1:6))
       ih=1
       do h3=-1,1,2
       do h4=-1,1,2
       do h5=-1,1,2
       do h6=-1,1,2
          if( ih.ge.17 ) cycle
          Helicities(ih,1:6) = (/0,0,h3,h4,h5,h6/)
          ih=ih+1
       enddo
       enddo
       enddo
       enddo
    ENDIF





ELSEIF( MASTERPROCESS.EQ.13 ) THEN

    ExtParticle(1)%PartType = ASTop_
    ExtParticle(2)%PartType = STop_
    ExtParticle(3)%PartType = AStr_
    ExtParticle(4)%PartType = Str_
    IF( Correction.EQ.0 ) THEN
      NumPrimAmps = 1
      NumBornAmps = 1
!       NumPrimAmps = 2  ; print *, "for crossed check"
!       NumBornAmps = 2  ; print *, "for crossed check"

    ELSEIF( Correction.EQ.1 ) THEN
      NumPrimAmps = 7
      NumBornAmps = 1
    ELSEIF( Correction.EQ.3 ) THEN

    ELSEIF( Correction.EQ.4 ) THEN
      NumPrimAmps = 1
      NumBornAmps = 1
    ELSEIF( Correction.EQ.5 ) THEN
      NumPrimAmps = 1
      NumBornAmps = 1
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( XTOPDECAYS.EQ.0 ) THEN
       NumHelicities = 4
       allocate(Helicities(1:NumHelicities,1:6))
       Helicities(1,1:4) = (/0,0,+1,+1/)
       Helicities(2,1:4) = (/0,0,+1,-1/)
       Helicities(3,1:4) = (/0,0,-1,+1/)
       Helicities(4,1:4) = (/0,0,-1,-1/)
    ELSEIF( XTOPDECAYS.EQ.3 ) THEN   
       NumHelicities = 16
       allocate(Helicities(1:NumHelicities,1:6))
       ih=1
       do h3=-1,1,2
       do h4=-1,1,2
       do h5=-1,1,2
       do h6=-1,1,2
          if( ih.ge.17 ) cycle
          Helicities(ih,1:6) = (/0,0,h3,h4,h5,h6/)
          ih=ih+1
       enddo
       enddo
       enddo
       enddo
    ENDIF





ELSEIF( MASTERPROCESS.EQ.14 ) THEN

    ExtParticle(1)%PartType = ASTop_
    ExtParticle(2)%PartType = STop_
    ExtParticle(3)%PartType = Glu_
    ExtParticle(4)%PartType = Glu_
    ExtParticle(5)%PartType = Glu_
    IF( Correction.EQ.2 ) THEN
      NumPrimAmps = 6
      NumBornAmps = 6
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( XTOPDECAYS.EQ.0 ) THEN
       NumHelicities = 8
       allocate(Helicities(1:NumHelicities,1:7))
       Helicities(1,1:5) = (/0,0,+1,+1,+1/)
       Helicities(2,1:5) = (/0,0,+1,-1,+1/)
       Helicities(3,1:5) = (/0,0,-1,+1,+1/)
       Helicities(4,1:5) = (/0,0,-1,-1,+1/)
       Helicities(5,1:5) = (/0,0,+1,+1,-1/)
       Helicities(6,1:5) = (/0,0,+1,-1,-1/)
       Helicities(7,1:5) = (/0,0,-1,+1,-1/)
       Helicities(8,1:5) = (/0,0,-1,-1,-1/)
    ELSEIF( XTOPDECAYS.EQ.3 ) THEN   
       NumHelicities = 32
       allocate(Helicities(1:NumHelicities,1:7))
       ih=1
       do h2=-1,1,2
       do h3=-1,1,2
       do h4=-1,1,2
       do h5=-1,1,2
       do h6=-1,1,2
          if( ih.ge.33 ) cycle
          Helicities(ih,1:7) = (/0,0,h2,h3,h4,h5,h6/)
          ih=ih+1
       enddo
       enddo
       enddo
       enddo
       enddo
    ENDIF



ELSEIF( MASTERPROCESS.EQ.15 ) THEN

    ExtParticle(1)%PartType = ASTop_
    ExtParticle(2)%PartType = STop_
    ExtParticle(3)%PartType = AStr_
    ExtParticle(4)%PartType = Str_
    ExtParticle(5)%PartType = Glu_
    IF( Correction.EQ.2 ) THEN
      NumPrimAmps = 4
      NumBornAmps = 4
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( XTOPDECAYS.EQ.0 ) THEN
       NumHelicities = 8
       allocate(Helicities(1:NumHelicities,1:7))
       Helicities(1,1:5) = (/0,0,+1,-1,+1/)
       Helicities(2,1:5) = (/0,0,-1,+1,+1/)
       Helicities(3,1:5) = (/0,0,+1,-1,-1/)
       Helicities(4,1:5) = (/0,0,-1,+1,-1/)
       Helicities(5,1:5) = (/0,0,+1,+1,+1/)
       Helicities(6,1:5) = (/0,0,-1,-1,+1/)
       Helicities(7,1:5) = (/0,0,-1,-1,-1/)
       Helicities(8,1:5) = (/0,0,+1,+1,-1/)

    ELSEIF( XTOPDECAYS.EQ.3 ) THEN   
       NumHelicities = 32
       allocate(Helicities(1:NumHelicities,1:7))
       ih=1
       do h2=-1,1,2
       do h3=-1,1,2
       do h4=-1,1,2
       do h5=-1,1,2
       do h6=-1,1,2
          if( ih.ge.33 ) cycle
          Helicities(ih,1:7) = (/0,0,h2,h3,h4,h5,h6/)
          ih=ih+1
       enddo
       enddo
       enddo
       enddo
       enddo
    ENDIF






ELSEIF( MASTERPROCESS.EQ.16 ) THEN

    ExtParticle(1)%PartType = ASTop_
    ExtParticle(2)%PartType = STop_
    ExtParticle(3)%PartType = AStr_
    ExtParticle(4)%PartType = Str_
!     ExtParticle(5)%PartType = Glu_
    ExtParticle(5)%PartType = AStop_
    ExtParticle(6)%PartType = STop_
    IF( Correction.LE.1 ) THEN
      NumPrimAmps = 2
      NumBornAmps = 2
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( XTOPDECAYS.EQ.0 ) THEN
       NumHelicities = 2
       allocate(Helicities(1:NumHelicities,1:6))
       Helicities(1,1:6) = (/0,0,+1,-1,0,0/)
       Helicities(2,1:6) = (/0,0,+1,+1,0,0/)
!        allocate(Helicities(1:NumHelicities,1:5))
!        Helicities(1,1:5) = (/0,0,+1,-1,+1/)
!        Helicities(2,1:5) = (/0,0,+1,-1,-1/)


    ELSEIF( XTOPDECAYS.EQ.3 ) THEN   
       call Error("Top decay not yet implemented for Masterprocess 16")
    ENDIF







ELSEIF( MASTERPROCESS.EQ.17 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = Glu_
    ExtParticle(4)%PartType = Glu_
    ExtParticle(5)%PartType = Z0_
    if( Process.ge.20 .and. Process.le.31 ) ExtParticle(5)%PartType = Pho_

    IF( Correction.EQ.0 .OR. Correction.EQ.4 .OR.Correction.EQ.5 ) THEN
      NumPrimAmps = 2
      NumBornAmps = 2
    ELSEIF( Correction.EQ.1 ) THEN
       NumPrimAmps = 12    ! this EXCLUDES ferm loop prims
       NumBornAmps = 12
       NumPrimAmps = NumPrimAmps+6   ! this includes the ferm loops with the Z attached to the loop -- RR
       NumBornAmps = NumBornAmps+6
       NumPrimAmps = NumPrimAmps+2   ! this includes the ferm loops with the Z attached to the top 
       NumBornAmps = NumBornAmps+2
       NumPrimAmps = NumPrimAmps+8   ! this includes the massive ferm loops
       NumBornAmps = NumBornAmps+8
       NumPrimAmps = NumPrimAmps+8   !added 1 Mar 2014
       NumBornAmps = NumBornAmps+8
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( TOPDECAYS.GE.1 ) THEN
       if (Zdecays .eq. 0) then
        NumHelicities = 12
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))
        Helicities(1,1:5) = (/0,0,+1,+1,+1/)
        Helicities(2,1:5) = (/0,0,+1,+1,-1/)
        Helicities(3,1:5) = (/0,0,+1,+1, 0/)! longitudinal polarization of massive V boson
        Helicities(4,1:5) = (/0,0,+1,-1,+1/)
        Helicities(5,1:5) = (/0,0,+1,-1,-1/)
        Helicities(6,1:5) = (/0,0,+1,-1, 0/)! longitudinal polarization of massive V boson
        Helicities(7,1:5) = (/0,0,-1,+1,+1/)
        Helicities(8,1:5) = (/0,0,-1,+1,-1/)
        Helicities(9,1:5) = (/0,0,-1,+1, 0/)! longitudinal polarization of massive V boson
        Helicities(10,1:5)= (/0,0,-1,-1,+1/)
        Helicities(11,1:5)= (/0,0,-1,-1,-1/)
        Helicities(12,1:5)= (/0,0,-1,-1, 0/)! longitudinal polarization of massive V boson
     else
         NumHelicities = 8
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))  ! extra for Z decay
        Helicities(1,1:5) = (/0,0,+1,+1,+1/)
        Helicities(2,1:5) = (/0,0,+1,+1,-1/)
        Helicities(3,1:5) = (/0,0,+1,-1,+1/)
        Helicities(4,1:5) = (/0,0,+1,-1,-1/)
        Helicities(5,1:5) = (/0,0,-1,+1,+1/)
        Helicities(6,1:5) = (/0,0,-1,+1,-1/)
        Helicities(7,1:5) = (/0,0,-1,-1,+1/)
        Helicities(8,1:5) = (/0,0,-1,-1,-1/)
     endif
    ELSE! .eq.0 or .eq.-1
       if (Zdecays.eq.0 .or. Zdecays.eq.-1 ) then!  -1: spin-uncorrelated
        NumHelicities = 48
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))
        sig_tb=+1; sig_t =+1;
        Helicities( 1,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
        Helicities( 2,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
        Helicities( 3,1:5) = (/sig_tb,sig_t,+1,+1, 0/)! longitudinal polarization of massive V boson
        Helicities( 4,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
        Helicities( 5,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
        Helicities( 6,1:5) = (/sig_tb,sig_t,+1,-1, 0/)! longitudinal polarization of massive V boson
        sig_tb=+1; sig_t =-1;
        Helicities( 7,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
        Helicities( 8,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
        Helicities( 9,1:5) = (/sig_tb,sig_t,+1,+1, 0/)! longitudinal polarization of massive V boson
        Helicities(10,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
        Helicities(11,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
        Helicities(12,1:5) = (/sig_tb,sig_t,+1,-1, 0/)! longitudinal polarization of massive V boson
        sig_tb=-1; sig_t =+1;
        Helicities(13,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
        Helicities(14,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
        Helicities(15,1:5) = (/sig_tb,sig_t,+1,+1, 0/)! longitudinal polarization of massive V boson
        Helicities(16,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
        Helicities(17,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
        Helicities(18,1:5) = (/sig_tb,sig_t,+1,-1, 0/)! longitudinal polarization of massive V boson
        sig_tb=-1; sig_t =-1;
        Helicities(19,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
        Helicities(20,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
        Helicities(21,1:5) = (/sig_tb,sig_t,+1,+1, 0/)! longitudinal polarization of massive V boson
        Helicities(22,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
        Helicities(23,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
        Helicities(24,1:5) = (/sig_tb,sig_t,+1,-1, 0/)! longitudinal polarization of massive V boson


    !   additional helicities when parity inversion is not applied:
        sig_tb=-1; sig_t =-1;
        Helicities(25,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
        Helicities(26,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
        Helicities(27,1:5) = (/sig_tb,sig_t,-1,-1, 0/)! longitudinal polarization of massive V boson
        Helicities(28,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
        Helicities(29,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
        Helicities(30,1:5) = (/sig_tb,sig_t,-1,+1, 0/)! longitudinal polarization of massive V boson
        sig_tb=-1; sig_t =+1;
        Helicities(31,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
        Helicities(32,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
        Helicities(33,1:5) = (/sig_tb,sig_t,-1,-1, 0/)! longitudinal polarization of massive V boson
        Helicities(34,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
        Helicities(35,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
        Helicities(36,1:5) = (/sig_tb,sig_t,-1,+1, 0/)! longitudinal polarization of massive V boson
        sig_tb=+1; sig_t =-1;
        Helicities(37,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
        Helicities(38,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
        Helicities(39,1:5) = (/sig_tb,sig_t,-1,-1, 0/)! longitudinal polarization of massive V boson
        Helicities(40,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
        Helicities(41,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
        Helicities(42,1:5) = (/sig_tb,sig_t,-1,+1, 0/)! longitudinal polarization of massive V boson
        sig_tb=+1; sig_t =+1;
        Helicities(43,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
        Helicities(44,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
        Helicities(45,1:5) = (/sig_tb,sig_t,-1,-1, 0/)! longitudinal polarization of massive V boson
        Helicities(46,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
        Helicities(47,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
        Helicities(48,1:5) = (/sig_tb,sig_t,-1,+1, 0/)! longitudinal polarization of massive V boson
     else
        NumHelicities = 32
          allocate(Helicities(1:NumHelicities,1:NumExtParticles))  ! extra for Z decay or photon
          ! for now, use all helicities. might be able to use some clever tricks later though...
          sig_tb=+1;sig_t=+1;
          Helicities(1,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
          Helicities(2,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
          Helicities(3,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
          Helicities(4,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
          Helicities(5,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
          Helicities(6,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
          Helicities(7,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
          Helicities(8,1:5) = (/sig_tb,sig_t,-1,+1,-1/)

          sig_tb=+1;sig_t=-1;
          Helicities(9,1:5) =  (/sig_tb,sig_t,+1,+1,+1/)
          Helicities(10,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
          Helicities(11,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
          Helicities(12,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
          Helicities(13,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
          Helicities(14,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
          Helicities(15,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
          Helicities(16,1:5) = (/sig_tb,sig_t,-1,-1,-1/)

          sig_tb=-1;sig_t=+1;
          Helicities(17,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
          Helicities(18,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
          Helicities(19,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
          Helicities(20,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
          Helicities(21,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
          Helicities(22,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
          Helicities(23,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
          Helicities(24,1:5) = (/sig_tb,sig_t,-1,-1,-1/)

          sig_tb=-1;sig_t=-1;
          Helicities(25,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
          Helicities(26,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
          Helicities(27,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
          Helicities(28,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
          Helicities(29,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
          Helicities(30,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
          Helicities(31,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
          Helicities(32,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
     endif
    ENDIF


ELSEIF( MASTERPROCESS.EQ.18 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = AStr_
    ExtParticle(4)%PartType = Str_
    ExtParticle(5)%PartType = Z0_
    if( Process.ge.20 .and. Process.le.31 ) ExtParticle(5)%PartType = Pho_

    IF( Correction.EQ.0 .OR. Correction.EQ.4 .OR.Correction.EQ.5) THEN
      NumPrimAmps = 2
      NumBornAmps = 2
    ELSEIF( Correction.EQ.1 ) THEN
       NumPrimAmps = 18
       NumBornAmps = 18
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( TOPDECAYS.GE.1 ) THEN
       if (ZDecays .ne. 0) then
       NumHelicities = 8 
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))  ! extra for Z decay
        Helicities(1,1:5) = (/0,0,+1,+1,+1/)
        Helicities(2,1:5) = (/0,0,+1,+1,-1/)
        Helicities(3,1:5) = (/0,0,+1,-1,+1/)
        Helicities(4,1:5) = (/0,0,+1,-1,-1/)
        Helicities(5,1:5) = (/0,0,-1,+1,+1/)
        Helicities(6,1:5) = (/0,0,-1,+1,-1/)
        Helicities(7,1:5) = (/0,0,-1,-1,+1/)
        Helicities(8,1:5) = (/0,0,-1,-1,-1/)
     else
        NumHelicities=12
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))
        Helicities(1,1:5) = (/0,0,+1,+1,+1/)
        Helicities(2,1:5) = (/0,0,+1,+1,-1/)
        Helicities(3,1:5) = (/0,0,+1,+1, 0/)! longitudinal polarization of massive V boson
        Helicities(4,1:5) = (/0,0,+1,-1,+1/)
        Helicities(5,1:5) = (/0,0,+1,-1,-1/)
        Helicities(6,1:5) = (/0,0,+1,-1, 0/)! longitudinal polarization of massive V boson
        Helicities(7,1:5) = (/0,0,-1,+1,+1/)
        Helicities(8,1:5) = (/0,0,-1,+1,-1/)
        Helicities(9,1:5) = (/0,0,-1,+1, 0/)! longitudinal polarization of massive V boson
        Helicities(10,1:5)= (/0,0,-1,-1,+1/)
        Helicities(11,1:5)= (/0,0,-1,-1,-1/)
        Helicities(12,1:5)= (/0,0,-1,-1, 0/)! longitudinal polarization of massive V boson
     endif
    ELSE
       if( abs(ZDecays) .gt. 0 ) then
          NumHelicities = 16
          allocate(Helicities(1:NumHelicities,1:NumExtParticles))  ! extra for Z decay
          ! for now, use all helicities. might be able to use some clever tricks later though...
          sig_tb=+1;sig_t=+1;
          Helicities(1,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
          Helicities(2,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
          Helicities(3,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
          Helicities(4,1:5) = (/sig_tb,sig_t,-1,+1,-1/)

          sig_tb=+1;sig_t=-1;
          Helicities(5,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
          Helicities(6,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
          Helicities(7,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
          Helicities(8,1:5) = (/sig_tb,sig_t,-1,+1,-1/)

          sig_tb=-1;sig_t=+1;
          Helicities(9,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
          Helicities(10,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
          Helicities(11,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
          Helicities(12,1:5) = (/sig_tb,sig_t,-1,+1,-1/)

          sig_tb=-1;sig_t=-1;
          Helicities(13,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
          Helicities(14,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
          Helicities(15,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
          Helicities(16,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
       else

        NumHelicities = 48
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))
        sig_tb=+1; sig_t =+1;
        Helicities( 1,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
        Helicities( 2,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
        Helicities( 3,1:5) = (/sig_tb,sig_t,+1,+1, 0/)! longitudinal polarization of massive V boson
        Helicities( 4,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
        Helicities( 5,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
        Helicities( 6,1:5) = (/sig_tb,sig_t,+1,-1, 0/)! longitudinal polarization of massive V boson
        sig_tb=+1; sig_t =-1;
        Helicities( 7,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
        Helicities( 8,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
        Helicities( 9,1:5) = (/sig_tb,sig_t,+1,+1, 0/)! longitudinal polarization of massive V boson
        Helicities(10,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
        Helicities(11,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
        Helicities(12,1:5) = (/sig_tb,sig_t,+1,-1, 0/)! longitudinal polarization of massive V boson
        sig_tb=-1; sig_t =+1;
        Helicities(13,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
        Helicities(14,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
        Helicities(15,1:5) = (/sig_tb,sig_t,+1,+1, 0/)! longitudinal polarization of massive V boson
        Helicities(16,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
        Helicities(17,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
        Helicities(18,1:5) = (/sig_tb,sig_t,+1,-1, 0/)! longitudinal polarization of massive V boson
        sig_tb=-1; sig_t =-1;
        Helicities(19,1:5) = (/sig_tb,sig_t,+1,+1,+1/)
        Helicities(20,1:5) = (/sig_tb,sig_t,+1,+1,-1/)
        Helicities(21,1:5) = (/sig_tb,sig_t,+1,+1, 0/)! longitudinal polarization of massive V boson
        Helicities(22,1:5) = (/sig_tb,sig_t,+1,-1,-1/)
        Helicities(23,1:5) = (/sig_tb,sig_t,+1,-1,+1/)
        Helicities(24,1:5) = (/sig_tb,sig_t,+1,-1, 0/)! longitudinal polarization of massive V boson

    !   additional helicities when parity inversion is not applied:
        sig_tb=-1; sig_t =-1;
        Helicities(25,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
        Helicities(26,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
        Helicities(27,1:5) = (/sig_tb,sig_t,-1,-1, 0/)! longitudinal polarization of massive V boson
        Helicities(28,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
        Helicities(29,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
        Helicities(30,1:5) = (/sig_tb,sig_t,-1,+1, 0/)! longitudinal polarization of massive V boson
        sig_tb=-1; sig_t =+1;
        Helicities(31,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
        Helicities(32,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
        Helicities(33,1:5) = (/sig_tb,sig_t,-1,-1, 0/)! longitudinal polarization of massive V boson
        Helicities(34,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
        Helicities(35,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
        Helicities(36,1:5) = (/sig_tb,sig_t,-1,+1, 0/)! longitudinal polarization of massive V boson
        sig_tb=+1; sig_t =-1;
        Helicities(37,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
        Helicities(38,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
        Helicities(39,1:5) = (/sig_tb,sig_t,-1,-1, 0/)! longitudinal polarization of massive V boson
        Helicities(40,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
        Helicities(41,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
        Helicities(42,1:5) = (/sig_tb,sig_t,-1,+1, 0/)! longitudinal polarization of massive V boson
        sig_tb=+1; sig_t =+1;
        Helicities(43,1:5) = (/sig_tb,sig_t,-1,-1,-1/)
        Helicities(44,1:5) = (/sig_tb,sig_t,-1,-1,+1/)
        Helicities(45,1:5) = (/sig_tb,sig_t,-1,-1, 0/)! longitudinal polarization of massive V boson
        Helicities(46,1:5) = (/sig_tb,sig_t,-1,+1,+1/)
        Helicities(47,1:5) = (/sig_tb,sig_t,-1,+1,-1/)
        Helicities(48,1:5) = (/sig_tb,sig_t,-1,+1, 0/)! longitudinal polarization of massive V boson
     endif
    ENDIF




ELSEIF( MASTERPROCESS.EQ.19 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = Glu_
    ExtParticle(4)%PartType = Glu_
    ExtParticle(5)%PartType = Glu_
    ExtParticle(6)%PartType = Z0_
    if( Process.ge.20 .and. Process.le.31 ) ExtParticle(6)%PartType = Pho_

    IF( Correction.EQ.2 ) THEN
      NumPrimAmps = 6
      NumBornAmps = 6
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo



    IF( TOPDECAYS.GE.1 .AND. ZDECAYS.EQ.0 ) THEN
    NumHelicities = 24
    allocate(Helicities(1:NumHelicities,1:NumExtParticles))
      ih=1
      do h3=-1,1,2
      do h4=-1,1,2
      do h5=-1,1,2
      do h6=-1,1,1! Z boson hel
          if( ih.ge.25 ) cycle
          Helicities(ih,1:6) = (/0,0,h3,h4,h5,h6/)
          ih=ih+1
      enddo
      enddo
      enddo
      enddo
    ELSEIF( TOPDECAYS.GE.1 .AND. ZDECAYS.GE.1 ) THEN
    NumHelicities = 16
    allocate(Helicities(1:NumHelicities,1:NumExtParticles))
      ih=1
      do h3=-1,1,2! Z boson hel. Markus: rearranged for TTBZ_Speed=.true.
      do h4=-1,1,2
      do h5=-1,1,2
      do h6=-1,1,2
          if( ih.ge.17 ) cycle
          Helicities(ih,1:6) = (/0,0,h6,h4,h5,h3/)
          ih=ih+1
      enddo
      enddo
      enddo
      enddo
    ELSEIF( TOPDECAYS.EQ.0 .AND. ZDECAYS.EQ.0 ) then
    NumHelicities = 96
    allocate(Helicities(1:NumHelicities,1:NumExtParticles))
      ih=1
      do h1=-1,1,2
      do h2=-1,1,2
      do h3=-1,1,2
      do h4=-1,1,2
      do h5=-1,1,2
      do h6=-1,1,1! Z boson hel
          if( ih.ge.97 ) cycle
          Helicities(ih,1:6) = (/h1,h2,h3,h4,h5,h6/)
          ih=ih+1
      enddo
      enddo
      enddo
      enddo
      enddo
      enddo
    ENDIF






ELSEIF( MASTERPROCESS.EQ.20 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = AStr_
    ExtParticle(4)%PartType = Str_
    ExtParticle(5)%PartType = Glu_
    ExtParticle(6)%PartType = Z0_
    if( Process.ge.20 .and. Process.le.31 ) ExtParticle(6)%PartType = Pho_

    IF( Correction.EQ.2 ) THEN
      NumPrimAmps = 8
      NumBornAmps = 8
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( TOPDECAYS.GE.1 .AND. ZDECAYS.EQ.0 ) THEN
    NumHelicities = 24
    allocate(Helicities(1:NumHelicities,1:NumExtParticles))
      ih=1
      do h3=-1,1,2
      do h4=-1,1,2
      do h5=-1,1,2
      do h6=-1,1,1! Z boson hel
          if( ih.ge.25 ) cycle
          Helicities(ih,1:6) = (/0,0,h3,h4,h5,h6/)
          ih=ih+1
      enddo
      enddo
      enddo
      enddo
    ELSEIF( TOPDECAYS.GE.1 .AND. ZDECAYS.GE.1 ) THEN
    NumHelicities = 16
    allocate(Helicities(1:NumHelicities,1:NumExtParticles))
      ih=1
      do h3=-1,1,2! Z boson hel. Markus: rearranged for TTBZ_Speed=.true.
      do h4=-1,1,2
      do h5=-1,1,2
      do h6=-1,1,2
          if( ih.ge.17 ) cycle
          Helicities(ih,1:6) = (/0,0,h6,h4,h5,h3/)
          ih=ih+1
      enddo
      enddo
      enddo
      enddo
    ELSEIF( TOPDECAYS.EQ.0 .AND. ZDECAYS.EQ.0 ) then
    NumHelicities = 96
    allocate(Helicities(1:NumHelicities,1:NumExtParticles))
      ih=1
      do h1=-1,1,2
      do h2=-1,1,2
      do h3=-1,1,2
      do h4=-1,1,2
      do h5=-1,1,2
      do h6=-1,1,1! Z boson hel
          if( ih.ge.97 ) cycle
          Helicities(ih,1:6) = (/h1,h2,h3,h4,h5,h6/)
          ih=ih+1
      enddo
      enddo
      enddo
      enddo
      enddo
      enddo

    ELSEIF( TOPDECAYS.EQ.0 .AND. ZDECAYS.EQ.-2 ) then!   ttbPhoton
    NumHelicities = 64
    allocate(Helicities(1:NumHelicities,1:NumExtParticles))
      ih=1
      do h1=-1,1,2
      do h2=-1,1,2
      do h3=-1,1,2
      do h4=-1,1,2
      do h5=-1,1,2
      do h6=-1,1,2! Z boson hel
          if( ih.ge.65 ) cycle
          Helicities(ih,1:6) = (/h1,h2,h3,h4,h5,h6/)
          ih=ih+1
      enddo
      enddo
      enddo
      enddo
      enddo
      enddo
    ENDIF




    
ELSEIF( MASTERPROCESS.EQ.21 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = ElP_
    ExtParticle(4)%PartType = ElM_
    NumPrimAmps = 0
    NumBornAmps = 0
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( TOPDECAYS.GE.1 ) THEN
              NumHelicities = 2
              allocate(Helicities(1:NumHelicities,1:NumExtParticles))
              Helicities(1,1:4) = (/0,0,-1,+1/)
              Helicities(2,1:4) = (/0,0,+1,-1/)
    ELSE
       NumHelicities = 8
       allocate(Helicities(1:NumHelicities,1:NumExtParticles))
       sig_tb=+1; sig_t =+1;
       Helicities(1,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
       Helicities(2,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
       sig_tb=+1; sig_t =-1;
       Helicities(3,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
       Helicities(4,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
       sig_tb=-1; sig_t =+1;
       Helicities(5,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
       Helicities(6,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
       sig_tb=-1; sig_t =-1;
       Helicities(7,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
       Helicities(8,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
    ENDIF

    
    
ELSEIF( MASTERPROCESS.EQ.22 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = ElP_
    ExtParticle(4)%PartType = ElM_
    ExtParticle(5)%PartType = Glu_

    NumPrimAmps = 0
    NumBornAmps = 0
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo
       
       IF( TOPDECAYS.GE.1 ) THEN
          NumHelicities = 4
          allocate(Helicities(1:NumHelicities,1:NumExtParticles))
          Helicities(1,1:5) = (/0,0,-1,+1,+1/)
          Helicities(3,1:5) = (/0,0,-1,+1,-1/)
          Helicities(2,1:5) = (/0,0,+1,-1,+1/)
          Helicities(4,1:5) = (/0,0,+1,-1,-1/)
       ELSE
          NumHelicities = 16
          allocate(Helicities(1:NumHelicities,1:NumExtParticles))
          sig_tb=+1; sig_t =+1;
          Helicities(1,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1,+1/)
          Helicities(9,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1,-1/)
          Helicities(2,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1,+1/)
          Helicities(10,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1,-1/)
          sig_tb=+1; sig_t =-1;
          Helicities(3,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1,+1/)
          Helicities(11,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1,-1/)
          Helicities(4,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1,+1/)
          Helicities(12,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1,-1/)
          sig_tb=-1; sig_t =+1;
          Helicities(5,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1,+1/)
          Helicities(13,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1,-1/)
          Helicities(6,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1,+1/)
          Helicities(14,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1,-1/)
          sig_tb=-1; sig_t =-1;
          Helicities(7,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1,+1/)
          Helicities(15,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1,-1/)
          Helicities(8,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1,+1/)
          Helicities(16,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1,-1/)

       ENDIF
    

    
    
    
    



ELSEIF( MASTERPROCESS.EQ.23 ) THEN    ! ttbH

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = Glu_
    ExtParticle(4)%PartType = Glu_
    ExtParticle(5)%PartType = Hig_

    IF( Correction.EQ.0 .OR. Correction.EQ.4 .OR.Correction.EQ.5 ) THEN
      NumPrimAmps = 2
      NumBornAmps = 2
    ELSEIF( Correction.EQ.1 ) THEN
        NumPrimAmps = 12    ! this EXCLUDES ferm loop prims
        NumBornAmps = 12
        NumPrimAmps = NumPrimAmps+2   ! light fermion loops with H attached to ext tops
        NumBornAmps = NumBornAmps+2
        NumPrimAmps = NumPrimAmps+2   ! massive ferm loops with gg on massive loop and H on external top line
        NumBornAmps = NumBornAmps+2
        NumPrimAmps = NumPrimAmps+4   ! massive ferm loops with gH on massive loop and g on external top line
        NumBornAmps = NumBornAmps+4
        NumPrimAmps = NumPrimAmps+6   ! massive ferm loops with ggH on massive loop
        NumBornAmps = NumBornAmps+6
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( TOPDECAYS.GE.1 ) THEN
        NumHelicities = 4
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))
        Helicities(1,1:5) = (/0,0,+1,+1, 0/)
        Helicities(2,1:5) = (/0,0,+1,-1, 0/)
        Helicities(3,1:5) = (/0,0,-1,+1, 0/)
        Helicities(4,1:5) = (/0,0,-1,-1, 0/)
    ELSE
        NumHelicities = 16
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))
        sig_tb=+1; sig_t =+1;
        Helicities( 1,1:5) = (/sig_tb,sig_t,+1,+1, 0/)
        Helicities( 2,1:5) = (/sig_tb,sig_t,+1,-1, 0/)
        sig_tb=+1; sig_t =-1;
        Helicities( 3,1:5) = (/sig_tb,sig_t,+1,+1, 0/)
        Helicities( 4,1:5) = (/sig_tb,sig_t,+1,-1, 0/)
        sig_tb=-1; sig_t =+1;
        Helicities( 5,1:5) = (/sig_tb,sig_t,+1,+1, 0/)
        Helicities( 6,1:5) = (/sig_tb,sig_t,+1,-1, 0/)
        sig_tb=-1; sig_t =-1;
        Helicities( 7,1:5) = (/sig_tb,sig_t,+1,+1, 0/)
        Helicities( 8,1:5) = (/sig_tb,sig_t,+1,-1, 0/)

    !   additional helicities when parity inversion is not applied:
        sig_tb=-1; sig_t =-1;
        Helicities( 9,1:5) = (/sig_tb,sig_t,-1,-1, 0/)
        Helicities(10,1:5) = (/sig_tb,sig_t,-1,+1, 0/)
        sig_tb=-1; sig_t =+1;
        Helicities(11,1:5) = (/sig_tb,sig_t,-1,-1, 0/)
        Helicities(12,1:5) = (/sig_tb,sig_t,-1,+1, 0/)
        sig_tb=+1; sig_t =-1;
        Helicities(13,1:5) = (/sig_tb,sig_t,-1,-1, 0/)
        Helicities(14,1:5) = (/sig_tb,sig_t,-1,+1, 0/)
        sig_tb=+1; sig_t =+1;
        Helicities(15,1:5) = (/sig_tb,sig_t,-1,-1, 0/)
        Helicities(16,1:5) = (/sig_tb,sig_t,-1,+1, 0/)
    ENDIF


ELSEIF( MASTERPROCESS.EQ.24 ) THEN            ! ttbH

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = AStr_
    ExtParticle(4)%PartType = Str_
    ExtParticle(5)%PartType = Hig_

    IF( Correction.EQ.0 .OR. Correction.EQ.4 .OR.Correction.EQ.5) THEN
      NumPrimAmps = 1
      NumBornAmps = 1
    ELSEIF( Correction.EQ.1 ) THEN
        NumPrimAmps = 5                    ! bosonic loops only
        NumBornAmps = 5
        NumPrimAmps = NumPrimAmps + 4      ! fermionic loops
        NumBornAmps = NumBornAmps + 4      
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( TOPDECAYS.GE.1 ) THEN
        NumHelicities = 2
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))
        Helicities(1,1:5) = (/0,0,+1,-1, 0/)
        Helicities(2,1:5) = (/0,0,-1,+1, 0/)
    ELSE
          NumHelicities = 8
          allocate(Helicities(1:NumHelicities,1:NumExtParticles))
          sig_tb=+1;sig_t=+1;
          Helicities(1,1:5) = (/sig_tb,sig_t,+1,-1, 0/)
          Helicities(2,1:5) = (/sig_tb,sig_t,-1,+1, 0/)

          sig_tb=+1;sig_t=-1;
          Helicities(3,1:5) = (/sig_tb,sig_t,+1,-1, 0/)
          Helicities(4,1:5) = (/sig_tb,sig_t,-1,+1, 0/)

          sig_tb=-1;sig_t=+1;
          Helicities(5,1:5) = (/sig_tb,sig_t,+1,-1, 0/)
          Helicities(6,1:5) = (/sig_tb,sig_t,-1,+1, 0/)

          sig_tb=-1;sig_t=-1;
          Helicities(7,1:5) = (/sig_tb,sig_t,+1,-1, 0/)
          Helicities(8,1:5) = (/sig_tb,sig_t,-1,+1, 0/)
    ENDIF




ELSEIF( MASTERPROCESS.EQ.25 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = Glu_
    ExtParticle(4)%PartType = Glu_
    ExtParticle(5)%PartType = Glu_
    ExtParticle(6)%PartType = Hig_

    IF( Correction.EQ.2 ) THEN
      NumPrimAmps = 6
      NumBornAmps = 6
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo



    IF( TOPDECAYS.GE.1 ) THEN
      NumHelicities = 4
      allocate(Helicities(1:NumHelicities,1:NumExtParticles))
        ih=1
!         do h3=-1,1,2
        do h3=-1,-1 ! use new feature in SetPolarizations
        do h4=-1,1,2
        do h5=-1,1,2
            if( ih.ge.5 ) cycle
            Helicities(ih,1:6) = (/0,0,h3,h4,h5, 0/)
            ih=ih+1
        enddo
        enddo
        enddo
    ELSEIF( TOPDECAYS.EQ.0 ) then
      NumHelicities = 16
      allocate(Helicities(1:NumHelicities,1:NumExtParticles))
        ih=1
        do h1=-1,1,2
        do h2=-1,1,2
!         do h3=-1,1,2
        do h3=-1,-1 ! use new feature in SetPolarizations
        do h4=-1,1,2
        do h5=-1,1,2
            if( ih.ge.17 ) cycle
            Helicities(ih,1:6) = (/h1,h2,h3,h4,h5, 0/)
            ih=ih+1
        enddo
        enddo
        enddo
        enddo
        enddo
    ENDIF






ELSEIF( MASTERPROCESS.EQ.26 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = AStr_
    ExtParticle(4)%PartType = Str_
    ExtParticle(5)%PartType = Glu_
    ExtParticle(6)%PartType = Hig_

    IF( Correction.EQ.2 ) THEN
      NumPrimAmps = 4
      NumBornAmps = 4
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo


    IF( TOPDECAYS.GE.1 ) THEN
!     NumHelicities = 8
    NumHelicities = 4
    allocate(Helicities(1:NumHelicities,1:NumExtParticles))
      ih=1
!       do h3=-1,1,2
      do h3=-1,-1 ! use new feature in SetPolarizations for quarks
!       do h4=-1,1,2
      do h4=-1,1,2
      do h5=-1,1,2
!       do h5=-1,-1 ! use new feature in SetPolarizations for gluons:currently not possible because of missing current
          if( ih.ge.NumHelicities+1 ) cycle
          Helicities(ih,1:6) = (/0,0,h3,h4,h5, 0/)
          ih=ih+1
      enddo
      enddo
      enddo
!       if( NumHelicities.eq.4 ) AvgFactor = AvgFactor*2
      
    ELSEIF( TOPDECAYS.EQ.0 ) then
!     NumHelicities = 16
    NumHelicities = 8
    allocate(Helicities(1:NumHelicities,1:NumExtParticles))
      ih=1
      do h1=-1,1,2
      do h2=-1,1,2
!       do h3=-1,1,2
      do h3=-1,-1 ! use new feature in SetPolarizations for quarks
!       do h4=-1,1,2
      do h4=-1,-1! this requires     AvgFactor = AvgFactor*2
      do h5=-1,1,2
!       do h5=-1,-1 ! use new feature in SetPolarizations for gluons
          if( ih.ge.NumHelicities+1 ) cycle
          Helicities(ih,1:6) = (/h1,h2,h3,h4,h5, 0/)
          ih=ih+1
      enddo
      enddo
      enddo
      enddo
      enddo
      if( NumHelicities.eq.8 ) AvgFactor = AvgFactor*2

    ENDIF    
    
    
!     IF( TOPDECAYS.GE.1 ) THEN
!     NumHelicities = 8
!     allocate(Helicities(1:NumHelicities,1:NumExtParticles))
!       ih=1
!       do h3=-1,1,2
!       do h4=-1,1,2
!       do h5=-1,1,2
!           if( ih.ge.9 ) cycle
!           Helicities(ih,1:6) = (/0,0,h3,h4,h5, 0/)
!           ih=ih+1
!       enddo
!       enddo
!       enddo
!     ELSEIF( TOPDECAYS.EQ.0 ) then
!     NumHelicities = 32
!     allocate(Helicities(1:NumHelicities,1:NumExtParticles))
!       ih=1
!       do h1=-1,1,2
!       do h2=-1,1,2
!       do h3=-1,1,2
!       do h4=-1,1,2
!       do h5=-1,1,2
!           if( ih.ge.33 ) cycle
!           Helicities(ih,1:6) = (/h1,h2,h3,h4,h5, 0/)
!           ih=ih+1
!       enddo
!       enddo
!       enddo
!       enddo
!       enddo
!     ENDIF

    
    



ELSEIF( MASTERPROCESS.EQ.31 ) THEN!  this is a copy of Masterprocess 1 which is used for virtual T'T' production

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = Glu_
    ExtParticle(4)%PartType = Glu_
    IF( Correction.EQ.1 ) THEN
      NumPrimAmps = 12
      NumBornAmps = 2
    ELSE
      call Error("Error in MASTERPROCESS.EQ.31")
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( XTOPDECAYS.GE.1 ) THEN
              NumHelicities = 4
              allocate(Helicities(1:NumHelicities,1:NumExtParticles))
              Helicities(1,1:4) = (/0,0,+1,+1/)
              Helicities(2,1:4) = (/0,0,+1,-1/)
              Helicities(3,1:4) = (/0,0,-1,+1/)
              Helicities(4,1:4) = (/0,0,-1,-1/)
    ELSE
              NumHelicities = 8
              allocate(Helicities(1:NumHelicities,1:NumExtParticles))
              sig_tb=+1; sig_t =+1;
              Helicities(1,1:NumExtParticles) = (/sig_tb,sig_t,+1,+1/)
              Helicities(2,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
              sig_tb=+1; sig_t =-1;
              Helicities(3,1:NumExtParticles) = (/sig_tb,sig_t,+1,+1/)
              Helicities(4,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
              sig_tb=-1; sig_t =+1;
              Helicities(5,1:NumExtParticles) = (/sig_tb,sig_t,+1,+1/)
              Helicities(6,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
              sig_tb=-1; sig_t =-1;
              Helicities(7,1:NumExtParticles) = (/sig_tb,sig_t,+1,+1/)
              Helicities(8,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
    !  additional helicities when parity inversion is not applied:    changes affect also EvalCS_ttb_NLODK_noSC
    !         sig_tb=+1; sig_t =+1;
    !         Helicities(9 ,1:NumExtParticles) = (/sig_tb,sig_t,-1,-1/)
    !         Helicities(10,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
    !         sig_tb=+1; sig_t =-1;
    !         Helicities(11,1:NumExtParticles) = (/sig_tb,sig_t,-1,-1/)
    !         Helicities(12,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
    !         sig_tb=-1; sig_t =+1;
    !         Helicities(13,1:NumExtParticles) = (/sig_tb,sig_t,-1,-1/)
    !         Helicities(14,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
    !         sig_tb=-1; sig_t =-1;
    !         Helicities(15,1:NumExtParticles) = (/sig_tb,sig_t,-1,-1/)
    !         Helicities(16,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
    ENDIF



ELSEIF( MASTERPROCESS.EQ.32 ) THEN!  this is a copy of Masterprocess 2 which is used for virtual T'T' production

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = AStr_
    ExtParticle(4)%PartType = Str_
    IF( Correction.EQ.1 ) THEN
      NumPrimAmps = 7
      NumBornAmps = 1
    ELSE
      call Error("Error in MASTERPROCESS.EQ.32")
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( XTOPDECAYS.GE.1 ) THEN
              NumHelicities = 4
              allocate(Helicities(1:NumHelicities,1:NumExtParticles))
              Helicities(1,1:4) = (/0,0,+1,+1/)
              Helicities(2,1:4) = (/0,0,+1,-1/)
              Helicities(3,1:4) = (/0,0,-1,+1/)
              Helicities(4,1:4) = (/0,0,-1,-1/)
    ELSE
      NumHelicities = 4
      allocate(Helicities(1:NumHelicities,1:NumExtParticles))
      sig_tb=+1; sig_t =+1;
  !    Helicities(1,1:NumExtParticles) = (/sig_tb,sig_t,+1,+1/)  ! the x,x,+1,+1 helicities lead to vanishing tree contribution
      Helicities(1,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
      sig_tb=+1; sig_t =-1;
  !    Helicities(3,1:NumExtParticles) = (/sig_tb,sig_t,+1,+1/)
      Helicities(2,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
      sig_tb=-1; sig_t =+1;
  !    Helicities(5,1:NumExtParticles) = (/sig_tb,sig_t,+1,+1/)
      Helicities(3,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
      sig_tb=-1; sig_t =-1;
  !    Helicities(7,1:NumExtParticles) = (/sig_tb,sig_t,+1,+1/)
      Helicities(4,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
  !   additional helicities when parity inversion is not applied: changes affect also EvalCS_ttb_NLODK_noSC
  !     sig_tb=+1; sig_t =+1;
  !     Helicities(9 ,1:NumExtParticles) = (/sig_tb,sig_t,-1,-1/)
  !     Helicities(10,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
  !     sig_tb=+1; sig_t =-1;
  !     Helicities(11,1:NumExtParticles) = (/sig_tb,sig_t,-1,-1/)
  !     Helicities(12,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
  !     sig_tb=-1; sig_t =+1;
  !     Helicities(13,1:NumExtParticles) = (/sig_tb,sig_t,-1,-1/)
  !     Helicities(14,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
  !     sig_tb=-1; sig_t =-1;
  !     Helicities(15,1:NumExtParticles) = (/sig_tb,sig_t,-1,-1/)
  !     Helicities(16,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
    ENDIF



ELSEIF( MASTERPROCESS.EQ.41 ) THEN

    ExtParticle(1)%PartType = ASTop_


ELSEIF( MASTERPROCESS.EQ.42 ) THEN

    ExtParticle(1)%PartType = STop_


ELSEIF( MASTERPROCESS.EQ.43 ) THEN

    ExtParticle(1)%PartType = ATop_


ELSEIF( MASTERPROCESS.EQ.44 ) THEN

    ExtParticle(1)%PartType = Top_


ELSEIF( MASTERPROCESS.EQ.45 ) THEN

    ExtParticle(1)%PartType = ATop_


ELSEIF( MASTERPROCESS.EQ.46 ) THEN

    ExtParticle(1)%PartType = Top_




    
ELSEIF( MASTERPROCESS.EQ.62 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = AStr_
    ExtParticle(4)%PartType = Str_
    IF( Correction.EQ.0 .OR. Correction.GE.4 ) THEN
      NumPrimAmps = 0
      NumBornAmps = 0
    ELSEIF( Correction.EQ.1 ) THEN
      NumPrimAmps = 0 
      NumBornAmps = 0
    ELSEIF( Correction.EQ.3 ) THEN
      NumPrimAmps = 0
      NumBornAmps = 0
    ELSEIF( Correction.EQ.4 ) THEN
       NumPrimAmps = 0
       NumBornAmps = 0
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( TOPDECAYS.GE.1 ) THEN
              NumHelicities = 2
              allocate(Helicities(1:NumHelicities,1:NumExtParticles))
              Helicities(1,1:4) = (/0,0,-1,+1/)
              Helicities(2,1:4) = (/0,0,+1,-1/)
    ELSE
      NumHelicities = 8
      allocate(Helicities(1:NumHelicities,1:NumExtParticles))
       sig_tb=+1; sig_t =+1;
       Helicities(1,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
       Helicities(2,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
       sig_tb=+1; sig_t =-1;
       Helicities(3,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
       Helicities(4,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
       sig_tb=-1; sig_t =+1;
       Helicities(5,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
       Helicities(6,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
       sig_tb=-1; sig_t =-1;
       Helicities(7,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1/)
       Helicities(8,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1/)
    ENDIF

ELSEIF( MASTERPROCESS.EQ.63 ) THEN

    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Top_
    ExtParticle(3)%PartType = AStr_
    ExtParticle(4)%PartType = Str_
    ExtParticle(5)%PartType = Glu_

    IF( Correction.EQ.0 .OR.  Correction.EQ.2 .OR.  Correction.EQ.4 ) THEN
      NumPrimAmps = 0
      NumBornAmps = 0
    ELSEIF( Correction.EQ.1 ) THEN
      NumPrimAmps = 0
      NumBornAmps = 0
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( PROCESS.EQ.66) THEN
       
       IF( TOPDECAYS.GE.1 ) THEN
          NumHelicities = 4
          allocate(Helicities(1:NumHelicities,1:NumExtParticles))
          Helicities(1,1:5) = (/0,0,-1,+1,+1/)
          Helicities(3,1:5) = (/0,0,-1,+1,-1/)
          Helicities(2,1:5) = (/0,0,+1,-1,+1/)
          Helicities(4,1:5) = (/0,0,+1,-1,-1/)
       ELSE
          NumHelicities = 16
          allocate(Helicities(1:NumHelicities,1:NumExtParticles))
          sig_tb=+1; sig_t =+1;
          Helicities(1,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1,+1/)
          Helicities(9,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1,-1/)
          Helicities(2,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1,+1/)
          Helicities(10,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1,-1/)
          sig_tb=+1; sig_t =-1;
          Helicities(3,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1,+1/)
          Helicities(11,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1,-1/)
          Helicities(4,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1,+1/)
          Helicities(12,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1,-1/)
          sig_tb=-1; sig_t =+1;
          Helicities(5,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1,+1/)
          Helicities(13,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1,-1/)
          Helicities(6,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1,+1/)
          Helicities(14,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1,-1/)
          sig_tb=-1; sig_t =-1;
          Helicities(7,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1,+1/)
          Helicities(15,1:NumExtParticles) = (/sig_tb,sig_t,+1,-1,-1/)
          Helicities(8,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1,+1/)
          Helicities(16,1:NumExtParticles) = (/sig_tb,sig_t,-1,+1,-1/)

       ENDIF

    ELSEIF ( PROCESS.EQ.63 .OR. PROCESS.EQ.64 ) THEN
       
       IF (TOPDECAYS .NE. 0 ) THEN
          NumHelicities = 8
          allocate(Helicities(1:NumHelicities,1:NumExtParticles))
          ih = 1
          do h3 = -1,1,2
             do h4 = -1,1,2
                do h5 = -1,1,2
                   Helicities(ih,:) = (/0,0,h3,h4,h5/)
                   ih = ih + 1
                enddo
             enddo
          enddo
       ELSE
          NumHelicities = 32
          allocate(Helicities(1:NumHelicities,1:NumExtParticles))
          ih = 1
          do h1 = -1,1,2
             do h2 = -1,1,2
                do h3 = -1,1,2
                   do h4 = -1,1,2
                      do h5 = -1,1,2
                         Helicities(ih,:) = (/h1,h2,h3,h4,h5/)
                         ih = ih + 1
                      enddo
                   enddo
                enddo
             enddo
          enddo
       ENDIF

    ENDIF


ELSEIF( MASTERPROCESS.EQ.73 ) THEN    ! t+H
    ExtParticle(1)%PartType = Top_
    ExtParticle(2)%PartType = Dn_
    ExtParticle(3)%PartType = Up_
    ExtParticle(4)%PartType = Bot_
    ExtParticle(5)%PartType = Hig_

    IF( Correction.EQ.0 ) THEN
      NumPrimAmps = 1
      NumBornAmps = 1
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( TOPDECAYS.GE.1 ) THEN
        NumHelicities = 1
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))
        Helicities( 1,1:5) = (/0,-1,-1,-1,0/)
    ELSE
        NumHelicities = 2
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))
        sig_t =+1;
        Helicities( 1,1:5) = (/sig_t,-1,-1,-1,0/)
        Helicities( 2,1:5) = (/sig_t,-1,-1,-1,0/)
                
    ENDIF
!    print *, "initialized in MasterProcess"

 ELSEIF( MASTERPROCESS.EQ.74 ) THEN    ! tb+H                                                                                                                         
    ExtParticle(1)%PartType = ATop_
    ExtParticle(2)%PartType = Dn_
    ExtParticle(3)%PartType = Up_
    ExtParticle(4)%PartType = ABot_
    ExtParticle(5)%PartType = Hig_

    IF( Correction.EQ.0 ) THEN
      NumPrimAmps = 1
      NumBornAmps = 1
    ENDIF
    allocate(PrimAmps(1:NumPrimAmps))
    allocate(BornAmps(1:NumPrimAmps))
    do NAmp=1,NumPrimAmps
        allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
        allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
    enddo

    IF( TOPDECAYS.GE.1 ) THEN
        NumHelicities = 4
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))
        Helicities(1,1:5) = (/0,0,+1,+1, 0/)
        Helicities(2,1:5) = (/0,0,+1,-1, 0/)
        Helicities(3,1:5) = (/0,0,-1,+1, 0/)
        Helicities(4,1:5) = (/0,0,-1,-1, 0/)
    ELSE
        NumHelicities = 16
        allocate(Helicities(1:NumHelicities,1:NumExtParticles))
        sig_tb=+1; sig_t =+1;
        Helicities( 1,1:5) = (/sig_tb,sig_t,+1,+1, 0/)
        Helicities( 2,1:5) = (/sig_tb,sig_t,+1,-1, 0/)
        sig_tb=+1; sig_t =-1;
        Helicities( 3,1:5) = (/sig_tb,sig_t,+1,+1, 0/)
        Helicities( 4,1:5) = (/sig_tb,sig_t,+1,-1, 0/)
        sig_tb=-1; sig_t =+1;
        Helicities( 5,1:5) = (/sig_tb,sig_t,+1,+1, 0/)
        Helicities( 6,1:5) = (/sig_tb,sig_t,+1,-1, 0/)
        sig_tb=-1; sig_t =-1;
        Helicities( 7,1:5) = (/sig_tb,sig_t,+1,+1, 0/)
        Helicities( 8,1:5) = (/sig_tb,sig_t,+1,-1, 0/)

    !   additional helicities when parity inversion is not applied:                                                                                                        
                                                                                                                                                                   
        sig_tb=-1; sig_t =-1;
        Helicities( 9,1:5) = (/sig_tb,sig_t,-1,-1, 0/)
        Helicities(10,1:5) = (/sig_tb,sig_t,-1,+1, 0/)
        sig_tb=-1; sig_t =+1;
        Helicities(11,1:5) = (/sig_tb,sig_t,-1,-1, 0/)
        Helicities(12,1:5) = (/sig_tb,sig_t,-1,+1, 0/)
        sig_tb=+1; sig_t =-1;
        Helicities(13,1:5) = (/sig_tb,sig_t,-1,-1, 0/)
        Helicities(14,1:5) = (/sig_tb,sig_t,-1,+1, 0/)
        sig_tb=+1; sig_t =+1;
        Helicities(15,1:5) = (/sig_tb,sig_t,-1,-1, 0/)
        Helicities(16,1:5) = (/sig_tb,sig_t,-1,+1, 0/)

    ENDIF






ELSE
    call Error("MasterProcess not implemented in InitMasterProcess")

ENDIF



   do NPart=1,NumExtParticles
         ExtParticle(NPart)%ExtRef = NPart
         ExtParticle(NPart)%Mass = GetMass( ExtParticle(NPart)%PartType )
         ExtParticle(NPart)%Mass2 = (ExtParticle(NPart)%Mass)**2
         ExtParticle(NPart)%Mom(1:8) = (0d0,0d0)
   enddo


END SUBROUTINE





SUBROUTINE RemoveProcess()
use modParameters
implicit none


      deallocate(Crossing)
      deallocate(ExtParticle)

      deallocate(PrimAmps)
      deallocate(BornAmps)

!         allocate(BornAmps(NAmp)%ExtLine(1:NumExtParticles))
!         allocate(PrimAmps(NAmp)%ExtLine(1:NumExtParticles))
!         allocate(PrimAmps(NAmp)%IntPart(1:NumExtParticles))
      deallocate(Helicities)

!       deallocate( TheTree%PartType(1:NumExtParticles), stat=AllocStatus )

!             allocate( TheTree%PartRef(1:NumExtParticles), stat=AllocStatus )

!                allocate( TheTree%NumGlu(0:TheTree%NumQua+TheTree%NumSca), stat=AllocStatus )
!                TheTree%NumGlu(0:TheTree%NumQua+TheTree%NumSca) = 0
!             elseif( TheTree%PartType(1).eq.Glu_ ) then
!                allocate( TheTree%NumGlu(0:TheTree%NumQua+TheTree%NumSca+1), stat=AllocStatus )


!            allocate( TheTree%Quarks(1:TheTree%NumQua), stat=AllocStatus )
!            allocate( TheTree%Scalars(1:TheTree%NumSca), stat=AllocStatus )
!            allocate( TheTree%Gluons(1:TheTree%NumGlu(0)), stat=AllocStatus )
            




END SUBROUTINE







SUBROUTINE InitAmps()
use ModMisc
use ModParameters
implicit none
integer :: Vertex,Propa,PropaMinus1,ExtPartType,NPrimAmp,k,LastQuark
integer :: AllocStatus,counterS,counterQ,counterG,counterV,QuarkPos(1:6),Scalarpos(1:6),NPart
logical :: ColorLessParticles
type(PrimitiveAmplitude),pointer :: ThePrimAmp
type(BornAmplitude),pointer :: TheBornAmp
type(TreeProcess),pointer :: TheTree
! RR for printout at end only
integer :: NPoint,NCut

! convention for labeling particles with 4 quarks: (1_tb, 2_t, 3_qb, 4_q)
! AmpType = 1/a:  1,2,3,4 (both fermion lines in loop)
! AmpType = 3/b:  1,4,3,2 (top line in loop)
! AmpType = 4/c:  1,2,3,4 (light fermion line in loop)
! AmpType = 2/d:  1,2,3,4 (closed fermion loop)
!  the ordering of the first PrimAmps should match the BornAmps because of the MassCT contribution


IF( Unweighted .and. Process.gt.01000000 ) RETURN

  do nPrimAmp = 1,NumPrimAmps
    PrimAmps(nPrimAmp)%NumSisters = 0
  enddo


IF( MASTERPROCESS.EQ.0 ) THEN
   BornAmps(1)%ExtLine = (/1,2,3,4,5,6,7/)
   PrimAmps(1)%ExtLine = (/1,2,3,4,5,6,7/)
   PrimAmps(1)%AmpType = 1



ELSEIF( MASTERPROCESS.EQ.1 ) THEN
   IF ( Correction.EQ.1 ) THEN
   BornAmps(1)%ExtLine = (/1,2,3,4/)
   BornAmps(2)%ExtLine = (/1,2,4,3/)

   PrimAmps(1)%ExtLine = (/1,2,3,4/)
   PrimAmp1_1234 = 2
   PrimAmps(1)%AmpType = 1

   PrimAmps(2)%ExtLine = (/1,2,4,3/)
   PrimAmp1_1243 = 1
   PrimAmps(2)%AmpType = 1

   PrimAmps(3)%ExtLine = (/1,3,2,4/)
   PrimAmp1_1324 = 3
   PrimAmps(3)%AmpType = 1

   PrimAmps(4)%ExtLine = (/1,4,2,3/)
   PrimAmp1_1423 = 4
   PrimAmps(4)%AmpType = 1

   PrimAmps(5)%ExtLine = (/1,3,4,2/)
   PrimAmp1_1342 = 6
   PrimAmps(5)%AmpType = 1

   PrimAmps(6)%ExtLine = (/1,4,3,2/)
   PrimAmp1_1432 = 5
   PrimAmps(6)%AmpType = 1

   PrimAmps(7)%ExtLine = (/1,2,3,4/)
   PrimAmp2_1234 = 1
   PrimAmps(7)%AmpType = 2
   PrimAmps(7)%FermLoopPart = Chm_

   PrimAmps(8)%ExtLine = (/1,2,4,3/)
   PrimAmp2_1243 = 2
   PrimAmps(8)%AmpType = 2
   PrimAmps(8)%FermLoopPart = Chm_

   PrimAmps(9)%ExtLine = (/1,2,3,4/)
   PrimAmp2m_1234 = 1
   PrimAmps(9)%AmpType = 2
   PrimAmps(9)%FermLoopPart = Bot_

   PrimAmps(10)%ExtLine = (/1,2,4,3/)
   PrimAmp2m_1243 = 2
   PrimAmps(10)%AmpType = 2
   PrimAmps(10)%FermLoopPart = Bot_

   ELSEIF( Correction.EQ.0 .OR. Correction.GE.4 ) THEN
   BornAmps(1)%ExtLine = (/1,2,3,4/)
   BornAmps(2)%ExtLine = (/1,2,4,3/)

   PrimAmps(1)%ExtLine = (/1,2,3,4/)
   PrimAmps(2)%ExtLine = (/1,2,4,3/)
   ENDIF


ELSEIF( MasterProcess.EQ.2) THEN
   IF( Correction.EQ.1 ) THEN
   BornAmps(1)%ExtLine = (/1,2,3,4/)
   BornAmps(2)%ExtLine = (/1,2,3,4/)
   BornAmps(3)%ExtLine = (/1,4,3,2/)
   BornAmps(4)%ExtLine = (/1,2,3,4/)
   BornAmps(5)%ExtLine = (/1,2,3,4/)
   BornAmps(6)%ExtLine = (/1,2,3,4/)

   PrimAmps(1)%ExtLine = (/1,2,3,4/)
   PrimAmp1_1234 = 1
   PrimAmps(1)%AmpType = 1

   PrimAmps(2)%ExtLine = (/1,2,4,3/)
   PrimAmp1_1243 = 2
   PrimAmps(2)%AmpType = 1

!    PrimAmps(3)%ExtLine = (/1,3,4,2/)
   PrimAmps(3)%ExtLine = (/1,4,3,2/)
   PrimAmp3_1432 = 3
   PrimAmps(3)%AmpType = 3

!    PrimAmps(4)%ExtLine = (/1,2,4,3/)
   PrimAmps(4)%ExtLine = (/1,2,3,4/)
   PrimAmp4_1234 = 4
   PrimAmps(4)%AmpType = 4

   PrimAmps(5)%ExtLine = (/1,2,3,4/)
   PrimAmp2_1234 = 5
   PrimAmps(5)%AmpType = 2
   PrimAmps(5)%FermLoopPart = Chm_

   PrimAmps(6)%ExtLine = (/1,2,3,4/)
   PrimAmp2m_1234 = 6
   PrimAmps(6)%AmpType = 2
   PrimAmps(6)%FermLoopPart = Bot_

   ELSEIF ( Correction.EQ.0 .OR. Correction.GE.4 ) THEN
   BornAmps(1)%ExtLine = (/1,2,3,4/)
   PrimAmps(1)%ExtLine = (/1,2,3,4/)
   ENDIF



ELSEIF( MasterProcess.EQ.3 ) THEN
   IF( Correction.EQ.1 ) THEN
   BornAmps(1)%ExtLine = (/1,2,3,4,5/)
   BornAmps(2)%ExtLine = (/1,2,3,5,4/)
   BornAmps(3)%ExtLine = (/1,2,4,3,5/)
   BornAmps(4)%ExtLine = (/1,2,4,5,3/)
   BornAmps(5)%ExtLine = (/1,2,5,3,4/)
   BornAmps(6)%ExtLine = (/1,2,5,4,3/)

   PrimAmps(1)%ExtLine = (/1,2,3,4,5/)
   PrimAmp1_12345 = 1
   PrimAmps(1)%AmpType = 1

   PrimAmps(2)%ExtLine = (/1,2,3,5,4/)
   PrimAmp1_12354 = 2
   PrimAmps(2)%AmpType = 1

   PrimAmps(3)%ExtLine = (/1,2,4,3,5/)
   PrimAmp1_12435 = 3
   PrimAmps(3)%AmpType = 1

   PrimAmps(4)%ExtLine = (/1,2,4,5,3/)
   PrimAmp1_12453 = 4
   PrimAmps(4)%AmpType = 1

   PrimAmps(5)%ExtLine = (/1,2,5,3,4/)
   PrimAmp1_12534 = 5
   PrimAmps(5)%AmpType = 1

   PrimAmps(6)%ExtLine = (/1,2,5,4,3/)
   PrimAmp1_12543 = 6
   PrimAmps(6)%AmpType = 1

!-------

   PrimAmps(7)%ExtLine = (/1,3,2,4,5/)
   PrimAmp1_13245 = 7
   PrimAmps(7)%AmpType = 1

   PrimAmps(8)%ExtLine = (/1,3,2,5,4/)
   PrimAmp1_13254 = 8
   PrimAmps(8)%AmpType = 1

   PrimAmps(9)%ExtLine = (/1,4,2,3,5/)
   PrimAmp1_14235 = 9
   PrimAmps(9)%AmpType = 1

   PrimAmps(10)%ExtLine = (/1,4,2,5,3/)
   PrimAmp1_14253 = 10
   PrimAmps(10)%AmpType = 1

   PrimAmps(11)%ExtLine = (/1,5,2,3,4/)
   PrimAmp1_15234 = 11
   PrimAmps(11)%AmpType = 1

   PrimAmps(12)%ExtLine = (/1,5,2,4,3/)
   PrimAmp1_15243 = 12
   PrimAmps(12)%AmpType = 1

!-------

   PrimAmps(13)%ExtLine = (/1,3,4,2,5/)
   PrimAmp1_13425 = 13
   PrimAmps(13)%AmpType = 1

   PrimAmps(14)%ExtLine = (/1,3,5,2,4/)
   PrimAmp1_13524 = 14
   PrimAmps(14)%AmpType = 1

   PrimAmps(15)%ExtLine = (/1,4,3,2,5/)
   PrimAmp1_14325 = 15
   PrimAmps(15)%AmpType = 1

   PrimAmps(16)%ExtLine = (/1,4,5,2,3/)
   PrimAmp1_14523 = 16
   PrimAmps(16)%AmpType = 1

   PrimAmps(17)%ExtLine = (/1,5,3,2,4/)
   PrimAmp1_15324 = 17
   PrimAmps(17)%AmpType = 1

   PrimAmps(18)%ExtLine = (/1,5,4,2,3/)
   PrimAmp1_15423 = 18
   PrimAmps(18)%AmpType = 1

!-------

   PrimAmps(19)%ExtLine = (/1,3,4,5,2/)
   PrimAmp1_13452 = 19
   PrimAmps(19)%AmpType = 1

   PrimAmps(20)%ExtLine = (/1,3,5,4,2/)
   PrimAmp1_13542 = 20
   PrimAmps(20)%AmpType = 1

   PrimAmps(21)%ExtLine = (/1,4,3,5,2/)
   PrimAmp1_14352 = 21
   PrimAmps(21)%AmpType = 1

   PrimAmps(22)%ExtLine = (/1,4,5,3,2/)
   PrimAmp1_14532 = 22
   PrimAmps(22)%AmpType = 1

   PrimAmps(23)%ExtLine = (/1,5,3,4,2/)
   PrimAmp1_15342 = 23
   PrimAmps(23)%AmpType = 1

   PrimAmps(24)%ExtLine = (/1,5,4,3,2/)
   PrimAmp1_15432 = 24
   PrimAmps(24)%AmpType = 1


!------- fermion loops (massless)


   PrimAmps(25)%ExtLine = (/1,2,3,4,5/)
!    PrimAmp1_12345 = 1
   PrimAmps(25)%AmpType = 2
   PrimAmps(25)%FermLoopPart = Chm_

   PrimAmps(26)%ExtLine = (/1,2,3,5,4/)
!    PrimAmp1_12354 = 2
   PrimAmps(26)%AmpType = 2
   PrimAmps(26)%FermLoopPart = Chm_

   PrimAmps(27)%ExtLine = (/1,2,4,3,5/)
!    PrimAmp1_12435 = 3
   PrimAmps(27)%AmpType = 2
   PrimAmps(27)%FermLoopPart = Chm_

   PrimAmps(28)%ExtLine = (/1,2,4,5,3/)
!    PrimAmp1_12453 = 4
   PrimAmps(28)%AmpType = 2
   PrimAmps(28)%FermLoopPart = Chm_

   PrimAmps(29)%ExtLine = (/1,2,5,3,4/)
!    PrimAmp1_12534 = 5
   PrimAmps(29)%AmpType = 2
   PrimAmps(29)%FermLoopPart = Chm_

   PrimAmps(30)%ExtLine = (/1,2,5,4,3/)
!    PrimAmp1_12543 = 6
   PrimAmps(30)%AmpType = 2
   PrimAmps(30)%FermLoopPart = Chm_

!-------

   PrimAmps(31)%ExtLine = (/1,3,2,4,5/)
!    PrimAmp1_13245 = 7
   PrimAmps(31)%AmpType = 2
   PrimAmps(31)%FermLoopPart = Chm_

   PrimAmps(32)%ExtLine = (/1,3,2,5,4/)
!    PrimAmp1_13254 = 8
   PrimAmps(32)%AmpType = 2
   PrimAmps(32)%FermLoopPart = Chm_

   PrimAmps(33)%ExtLine = (/1,4,2,3,5/)
!    PrimAmp1_14235 = 9
   PrimAmps(33)%AmpType = 2
   PrimAmps(33)%FermLoopPart = Chm_

   PrimAmps(34)%ExtLine = (/1,4,2,5,3/)
!    PrimAmp1_14253 = 10
   PrimAmps(34)%AmpType = 2
   PrimAmps(34)%FermLoopPart = Chm_

   PrimAmps(35)%ExtLine = (/1,5,2,3,4/)
!    PrimAmp1_15234 = 11
   PrimAmps(35)%AmpType = 2
   PrimAmps(35)%FermLoopPart = Chm_

   PrimAmps(36)%ExtLine = (/1,5,2,4,3/)
!    PrimAmp1_15243 = 12
   PrimAmps(36)%AmpType = 2
   PrimAmps(36)%FermLoopPart = Chm_


!------- fermion loops (massive)


   PrimAmps(37)%ExtLine = (/1,2,3,4,5/)
!    PrimAmp1_12345 = 1
   PrimAmps(37)%AmpType = 2
   PrimAmps(37)%FermLoopPart = Bot_

   PrimAmps(38)%ExtLine = (/1,2,3,5,4/)
!    PrimAmp1_12354 = 2
   PrimAmps(38)%AmpType = 2
   PrimAmps(38)%FermLoopPart = Bot_

   PrimAmps(39)%ExtLine = (/1,2,4,3,5/)
!    PrimAmp1_12435 = 3
   PrimAmps(39)%AmpType = 2
   PrimAmps(39)%FermLoopPart = Bot_

   PrimAmps(40)%ExtLine = (/1,2,4,5,3/)
!    PrimAmp1_12453 = 4
   PrimAmps(40)%AmpType = 2
   PrimAmps(40)%FermLoopPart = Bot_

   PrimAmps(41)%ExtLine = (/1,2,5,3,4/)
!    PrimAmp1_12534 = 5
   PrimAmps(41)%AmpType = 2
   PrimAmps(41)%FermLoopPart = Bot_

   PrimAmps(42)%ExtLine = (/1,2,5,4,3/)
!    PrimAmp1_12543 = 6
   PrimAmps(42)%AmpType = 2
   PrimAmps(42)%FermLoopPart = Bot_

!-------

   PrimAmps(43)%ExtLine = (/1,3,2,4,5/)
!    PrimAmp1_13245 = 7
   PrimAmps(43)%AmpType = 2
   PrimAmps(43)%FermLoopPart = Bot_

   PrimAmps(44)%ExtLine = (/1,3,2,5,4/)
!    PrimAmp1_13254 = 8
   PrimAmps(44)%AmpType = 2
   PrimAmps(44)%FermLoopPart = Bot_

   PrimAmps(45)%ExtLine = (/1,4,2,3,5/)
!    PrimAmp1_14235 = 9
   PrimAmps(45)%AmpType = 2
   PrimAmps(45)%FermLoopPart = Bot_

   PrimAmps(46)%ExtLine = (/1,4,2,5,3/)
!    PrimAmp1_14253 = 10
   PrimAmps(46)%AmpType = 2
   PrimAmps(46)%FermLoopPart = Bot_

   PrimAmps(47)%ExtLine = (/1,5,2,3,4/)
!    PrimAmp1_15234 = 11
   PrimAmps(47)%AmpType = 2
   PrimAmps(47)%FermLoopPart = Bot_

   PrimAmps(48)%ExtLine = (/1,5,2,4,3/)
!    PrimAmp1_15243 = 12
   PrimAmps(48)%AmpType = 2
   PrimAmps(48)%FermLoopPart = Bot_


   ELSEIF( Correction.EQ.0 .OR. Correction.EQ.2 .OR. Correction.EQ.4 ) THEN
   BornAmps(1)%ExtLine = (/1,2,3,4,5/)
   BornAmps(2)%ExtLine = (/1,2,3,5,4/)
   BornAmps(3)%ExtLine = (/1,2,4,3,5/)
   BornAmps(4)%ExtLine = (/1,2,4,5,3/)
   BornAmps(5)%ExtLine = (/1,2,5,3,4/)
   BornAmps(6)%ExtLine = (/1,2,5,4,3/)

   PrimAmps(1)%ExtLine = (/1,2,3,4,5/)
   PrimAmps(2)%ExtLine = (/1,2,3,5,4/)
   PrimAmps(3)%ExtLine = (/1,2,4,3,5/)
   PrimAmps(4)%ExtLine = (/1,2,4,5,3/)
   PrimAmps(5)%ExtLine = (/1,2,5,3,4/)
   PrimAmps(6)%ExtLine = (/1,2,5,4,3/)
   ENDIF



ELSEIF( MasterProcess.EQ.4 ) THEN
   IF( Correction.EQ.0 .OR. Correction.EQ.2 .OR. Correction.EQ.4 ) THEN
   PrimAmps(1)%ExtLine = (/1,2,3,4,5/)
   PrimAmps(2)%ExtLine = (/1,5,2,3,4/)
   PrimAmps(3)%ExtLine = (/1,2,5,3,4/)
   PrimAmps(4)%ExtLine = (/1,2,3,5,4/)

   ELSEIF( Correction.EQ.1 ) THEN
!    BornAmps(1)%ExtLine = (/1,2,3,4,5/)  ! will be overwritten anyways
!    BornAmps(2)%ExtLine = (/1,5,2,3,4/)
!    BornAmps(3)%ExtLine = (/1,2,5,3,4/)
!    BornAmps(4)%ExtLine = (/1,2,3,5,4/)

   PrimAmps(1)%ExtLine = (/1,2,3,4,5/)
   PrimAmp1_12345 = 1
   PrimAmps(1)%AmpType = 1

   PrimAmps(2)%ExtLine = (/1,5,2,3,4/)
   PrimAmp1_15234 = 2
   PrimAmps(2)%AmpType = 1

   PrimAmps(3)%ExtLine = (/1,2,5,3,4/)
   PrimAmp1_12534 = 3
   PrimAmps(3)%AmpType = 1

   PrimAmps(4)%ExtLine = (/1,2,3,5,4/)
   PrimAmp1_12354 = 4
   PrimAmps(4)%AmpType = 1

   PrimAmps(5)%ExtLine = (/1,2,5,4,3/)
   PrimAmp1_12543 = 5
   PrimAmps(5)%AmpType = 1

   PrimAmps(6)%ExtLine = (/1,2,4,3,5/)
   PrimAmp1_12435 = 6
   PrimAmps(6)%AmpType = 1

   PrimAmps(7)%ExtLine = (/1,2,4,5,3/)
   PrimAmp1_12453 = 7
   PrimAmps(7)%AmpType = 1

   PrimAmps(8)%ExtLine = (/1,5,2,4,3/)
   PrimAmp1_15243 = 8
   PrimAmps(8)%AmpType = 1



   PrimAmps(9)%ExtLine = (/1,5,4,3,2/)
   PrimAmp3_15432 = 9
   PrimAmps(9)%AmpType = 3

   PrimAmps(10)%ExtLine = (/1,4,5,3,2/)
   PrimAmp3_14532 = 10
   PrimAmps(10)%AmpType = 3

   PrimAmps(11)%ExtLine = (/1,4,3,5,2/)
   PrimAmp3_14352 = 11
   PrimAmps(11)%AmpType = 3

   PrimAmps(12)%ExtLine = (/1,4,3,2,5/)
   PrimAmp3_14325 = 12
   PrimAmps(12)%AmpType = 3



   PrimAmps(13)%ExtLine = (/1,2,3,5,4/)
   PrimAmp4_12354 = 13
   PrimAmps(13)%AmpType = 4

   PrimAmps(14)%ExtLine = (/1,2,5,3,4/)
   PrimAmp4_12534 = 14
   PrimAmps(14)%AmpType = 4

   PrimAmps(15)%ExtLine = (/1,5,2,3,4/)
   PrimAmp4_15234 = 15
   PrimAmps(15)%AmpType = 4

   PrimAmps(16)%ExtLine = (/1,2,3,4,5/)
   PrimAmp4_12345 = 16
   PrimAmps(16)%AmpType = 4


!------- fermion loops (massless)

   PrimAmps(17)%ExtLine = (/1,2,3,4,5/)
   PrimAmp2_12345 = 17
   PrimAmps(17)%AmpType = 2
   PrimAmps(17)%FermLoopPart = Chm_

   PrimAmps(18)%ExtLine = (/1,5,2,3,4/)
   PrimAmp2_15234 = 18
   PrimAmps(18)%AmpType = 2
   PrimAmps(18)%FermLoopPart = Chm_

   PrimAmps(19)%ExtLine = (/1,2,5,3,4/)
   PrimAmp2_12534 = 19
   PrimAmps(19)%AmpType = 2
   PrimAmps(19)%FermLoopPart = Chm_

   PrimAmps(20)%ExtLine = (/1,2,3,5,4/)
   PrimAmp2_12354 = 20
   PrimAmps(20)%AmpType = 2
   PrimAmps(20)%FermLoopPart = Chm_

!------- fermion loops (massive)

   PrimAmps(21)%ExtLine = (/1,2,3,4,5/)
   PrimAmp2m_12345 = 21
   PrimAmps(21)%AmpType = 2
   PrimAmps(21)%FermLoopPart = Bot_

   PrimAmps(22)%ExtLine = (/1,5,2,3,4/)
   PrimAmp2m_15234 = 22
   PrimAmps(22)%AmpType = 2
   PrimAmps(22)%FermLoopPart = Bot_

   PrimAmps(23)%ExtLine = (/1,2,5,3,4/)
   PrimAmp2m_12534 = 23
   PrimAmps(23)%AmpType = 2
   PrimAmps(23)%FermLoopPart = Bot_

   PrimAmps(24)%ExtLine = (/1,2,3,5,4/)
   PrimAmp2m_12354 = 24
   PrimAmps(24)%AmpType = 2
   PrimAmps(24)%FermLoopPart = Bot_
   ENDIF

ELSEIF( MasterProcess.EQ.5 ) THEN
   IF( Correction.EQ.2 ) THEN
   BornAmps( 1)%ExtLine = (/1,2,3, 4, 5, 6/)
   BornAmps( 2)%ExtLine = (/1,2,3, 4, 6, 5/)
   BornAmps( 3)%ExtLine = (/1,2,3, 5, 4, 6/)
   BornAmps( 4)%ExtLine = (/1,2,3, 5, 6, 4/)
   BornAmps( 5)%ExtLine = (/1,2,3, 6, 4, 5/)
   BornAmps( 6)%ExtLine = (/1,2,3, 6, 5, 4/)
   BornAmps( 7)%ExtLine = (/1,2,4, 3, 5, 6/)
   BornAmps( 8)%ExtLine = (/1,2,4, 3, 6, 5/)
   BornAmps( 9)%ExtLine = (/1,2,4, 5, 3, 6/)
   BornAmps(10)%ExtLine = (/1,2,4, 5, 6, 3/)
   BornAmps(11)%ExtLine = (/1,2,4, 6, 3, 5/)
   BornAmps(12)%ExtLine = (/1,2,4, 6, 5, 3/)
   BornAmps(13)%ExtLine = (/1,2,5, 3, 4, 6/)
   BornAmps(14)%ExtLine = (/1,2,5, 3, 6, 4/)
   BornAmps(15)%ExtLine = (/1,2,5, 4, 3, 6/)
   BornAmps(16)%ExtLine = (/1,2,5, 4, 6, 3/)
   BornAmps(17)%ExtLine = (/1,2,5, 6, 3, 4/)
   BornAmps(18)%ExtLine = (/1,2,5, 6, 4, 3/)
   BornAmps(19)%ExtLine = (/1,2,6, 3, 4, 5/)
   BornAmps(20)%ExtLine = (/1,2,6, 3, 5, 4/)
   BornAmps(21)%ExtLine = (/1,2,6, 4, 3, 5/)
   BornAmps(22)%ExtLine = (/1,2,6, 4, 5, 3/)
   BornAmps(23)%ExtLine = (/1,2,6, 5, 3, 4/)
   BornAmps(24)%ExtLine = (/1,2,6, 5, 4, 3/)


   PrimAmps( 1)%ExtLine = (/1,2,3, 4, 5, 6/)
   PrimAmps( 2)%ExtLine = (/1,2,3, 4, 6, 5/)
   PrimAmps( 3)%ExtLine = (/1,2,3, 5, 4, 6/)
   PrimAmps( 4)%ExtLine = (/1,2,3, 5, 6, 4/)
   PrimAmps( 5)%ExtLine = (/1,2,3, 6, 4, 5/)
   PrimAmps( 6)%ExtLine = (/1,2,3, 6, 5, 4/)
   PrimAmps( 7)%ExtLine = (/1,2,4, 3, 5, 6/)
   PrimAmps( 8)%ExtLine = (/1,2,4, 3, 6, 5/)
   PrimAmps( 9)%ExtLine = (/1,2,4, 5, 3, 6/)
   PrimAmps(10)%ExtLine = (/1,2,4, 5, 6, 3/)
   PrimAmps(11)%ExtLine = (/1,2,4, 6, 3, 5/)
   PrimAmps(12)%ExtLine = (/1,2,4, 6, 5, 3/)
   PrimAmps(13)%ExtLine = (/1,2,5, 3, 4, 6/)
   PrimAmps(14)%ExtLine = (/1,2,5, 3, 6, 4/)
   PrimAmps(15)%ExtLine = (/1,2,5, 4, 3, 6/)
   PrimAmps(16)%ExtLine = (/1,2,5, 4, 6, 3/)
   PrimAmps(17)%ExtLine = (/1,2,5, 6, 3, 4/)
   PrimAmps(18)%ExtLine = (/1,2,5, 6, 4, 3/)
   PrimAmps(19)%ExtLine = (/1,2,6, 3, 4, 5/)
   PrimAmps(20)%ExtLine = (/1,2,6, 3, 5, 4/)
   PrimAmps(21)%ExtLine = (/1,2,6, 4, 3, 5/)
   PrimAmps(22)%ExtLine = (/1,2,6, 4, 5, 3/)
   PrimAmps(23)%ExtLine = (/1,2,6, 5, 3, 4/)
   PrimAmps(24)%ExtLine = (/1,2,6, 5, 4, 3/)
   ENDIF

ELSEIF( MasterProcess.EQ.6 ) THEN
   IF( Correction.EQ.2 ) THEN
   BornAmps( 1)%ExtLine = (/1,2,3,4,5,6/)
   BornAmps( 2)%ExtLine = (/1,2,3,4,6,5/)
   BornAmps( 3)%ExtLine = (/1,2,5,6,3,4/)
   BornAmps( 4)%ExtLine = (/1,2,6,5,3,4/)
   BornAmps( 5)%ExtLine = (/1,2,5,3,4,6/)
   BornAmps( 6)%ExtLine = (/1,2,6,3,4,5/)
   BornAmps( 7)%ExtLine = (/1,5,6,2,3,4/)
   BornAmps( 8)%ExtLine = (/1,6,5,2,3,4/)
   BornAmps( 9)%ExtLine = (/1,5,2,3,6,4/)
   BornAmps(10)%ExtLine = (/1,6,2,3,5,4/)
   BornAmps(11)%ExtLine = (/1,2,3,5,6,4/)
   BornAmps(12)%ExtLine = (/1,2,3,6,5,4/)

   PrimAmps( 1)%ExtLine = (/1,2,3,4,5,6/)
   PrimAmps( 2)%ExtLine = (/1,2,3,4,6,5/)
   PrimAmps( 3)%ExtLine = (/1,2,5,6,3,4/)
   PrimAmps( 4)%ExtLine = (/1,2,6,5,3,4/)
   PrimAmps( 5)%ExtLine = (/1,2,5,3,4,6/)
   PrimAmps( 6)%ExtLine = (/1,2,6,3,4,5/)
   PrimAmps( 7)%ExtLine = (/1,5,6,2,3,4/)
   PrimAmps( 8)%ExtLine = (/1,6,5,2,3,4/)
   PrimAmps( 9)%ExtLine = (/1,5,2,3,6,4/)
   PrimAmps(10)%ExtLine = (/1,6,2,3,5,4/)
   PrimAmps(11)%ExtLine = (/1,2,3,5,6,4/)
   PrimAmps(12)%ExtLine = (/1,2,3,6,5,4/)
   ENDIF

ELSEIF( MasterProcess.EQ.7 ) THEN
! there's nothing to do here

ELSEIF( MasterProcess.EQ.8 ) THEN! tb t g g pho

   IF( Correction.EQ.0 .OR. Correction.EQ.4 .OR.Correction.EQ.5 ) THEN
      BornAmps(1)%ExtLine = (/1,5,2,3,4/)
      BornAmps(2)%ExtLine = (/1,5,2,4,3/)

      PrimAmps(1)%ExtLine = (/1,5,2,3,4/)
      PrimAmps(2)%ExtLine = (/1,5,2,4,3/)
   ELSEIF( Correction.EQ.1 ) THEN
      BornAmps(1)%ExtLine = (/1,5,2,3,4/)
      BornAmps(2)%ExtLine = (/1,5,2,4,3/)

      PrimAmps(1)%ExtLine = (/1,5,2,3,4/)
      PrimAmp1_15234 = 1
      PrimAmps(1)%AmpType = 1

      PrimAmps(2)%ExtLine = (/1,5,2,4,3/)
      PrimAmp1_15243 = 2
      PrimAmps(2)%AmpType = 1

      PrimAmps(3)%ExtLine = (/1,3,5,4,2/)
      PrimAmp1_13542 = 3
      PrimAmps(3)%AmpType = 1

      PrimAmps(4)%ExtLine = (/1,3,4,5,2/)
      PrimAmp1_13452 = 4
      PrimAmps(4)%AmpType = 1

      PrimAmps(5)%ExtLine = (/1,5,3,4,2/)
      PrimAmp1_15342 = 5
      PrimAmps(5)%AmpType = 1

      PrimAmps(6)%ExtLine = (/1,5,4,3,2/)
      PrimAmp1_15432 = 6
      PrimAmps(6)%AmpType = 1

      PrimAmps(7)%ExtLine = (/1,4,5,3,2/)
      PrimAmp1_14532 = 7
      PrimAmps(7)%AmpType = 1

      PrimAmps(8)%ExtLine = (/1,4,3,5,2/)
      PrimAmp1_14352 = 8
      PrimAmps(8)%AmpType = 1

      PrimAmps(9)%ExtLine = (/1,5,3,2,4/)
      PrimAmp1_15324 = 9
      PrimAmps(9)%AmpType = 1

      PrimAmps(10)%ExtLine = (/1,3,5,2,4/)
      PrimAmp1_13524 = 10
      PrimAmps(10)%AmpType = 1

      PrimAmps(11)%ExtLine = (/1,5,4,2,3/)
      PrimAmp1_15423 = 11
      PrimAmps(11)%AmpType = 1

      PrimAmps(12)%ExtLine = (/1,4,5,2,3/)
      PrimAmp1_14523 = 12
      PrimAmps(12)%AmpType = 1




      PrimAmps(13)%ExtLine = (/1,5,2,3,4/)
      PrimAmp2_15234 = 13
      PrimAmps(13)%AmpType = 2
      PrimAmps(13)%FermLoopPart = Chm_

      PrimAmps(14)%ExtLine = (/1,2,3,4,5/)
      PrimAmp2_12345 = 14
      PrimAmps(14)%AmpType = 2
      PrimAmps(14)%FermLoopPart = Chm_

      PrimAmps(15)%ExtLine = (/1,2,3,5,4/)
      PrimAmp2_12354 = 15
      PrimAmps(15)%AmpType = 2
      PrimAmps(15)%FermLoopPart = Chm_

      PrimAmps(16)%ExtLine = (/1,2,5,3,4/)
      PrimAmp2_12534 = 16
      PrimAmps(16)%AmpType = 2
      PrimAmps(16)%FermLoopPart = Chm_

      PrimAmps(17)%ExtLine = (/1,5,2,4,3/)
      PrimAmp2_15243 = 17
      PrimAmps(17)%AmpType = 2
      PrimAmps(17)%FermLoopPart = Chm_

      PrimAmps(18)%ExtLine = (/1,2,5,4,3/)
      PrimAmp2_12543 = 18
      PrimAmps(18)%AmpType = 2
      PrimAmps(18)%FermLoopPart = Chm_

      PrimAmps(19)%ExtLine = (/1,2,4,5,3/)
      PrimAmp2_12453 = 19
      PrimAmps(19)%AmpType = 2
      PrimAmps(19)%FermLoopPart = Chm_

      PrimAmps(20)%ExtLine = (/1,2,4,3,5/)
      PrimAmp2_12435 = 20
      PrimAmps(20)%AmpType = 2
      PrimAmps(20)%FermLoopPart = Chm_




      PrimAmps(21)%ExtLine = (/1,5,2,3,4/)
      PrimAmp2m_15234 = 21
      PrimAmps(21)%AmpType = 2
      PrimAmps(21)%FermLoopPart = Bot_

      PrimAmps(22)%ExtLine = (/1,2,3,4,5/)
      PrimAmp2m_12345 = 22
      PrimAmps(22)%AmpType = 2
      PrimAmps(22)%FermLoopPart = Bot_

      PrimAmps(23)%ExtLine = (/1,2,3,5,4/)
      PrimAmp2m_12354 = 23
      PrimAmps(23)%AmpType = 2
      PrimAmps(23)%FermLoopPart = Bot_

      PrimAmps(24)%ExtLine = (/1,2,5,3,4/)
      PrimAmp2m_12534 = 24
      PrimAmps(24)%AmpType = 2
      PrimAmps(24)%FermLoopPart = Bot_

      PrimAmps(25)%ExtLine = (/1,5,2,4,3/)
      PrimAmp2m_15243 = 25
      PrimAmps(25)%AmpType = 2
      PrimAmps(25)%FermLoopPart = Bot_

      PrimAmps(26)%ExtLine = (/1,2,5,4,3/)
      PrimAmp2m_12543 = 26
      PrimAmps(26)%AmpType = 2
      PrimAmps(26)%FermLoopPart = Bot_

      PrimAmps(27)%ExtLine = (/1,2,4,5,3/)
      PrimAmp2m_12453 = 27
      PrimAmps(27)%AmpType = 2
      PrimAmps(27)%FermLoopPart = Bot_

      PrimAmps(28)%ExtLine = (/1,2,4,3,5/)
      PrimAmp2m_12435 = 28
      PrimAmps(28)%AmpType = 2
      PrimAmps(28)%FermLoopPart = Bot_


   ENDIF


ELSEIF( MASTERPROCESS.EQ.9 ) THEN! tb t qb q pho

   IF( Correction.EQ.0  .OR. Correction.EQ.4 .OR.Correction.EQ.5 ) THEN
      BornAmps(1)%ExtLine = (/1,5,2,3,4/)
      BornAmps(2)%ExtLine = (/1,2,3,5,4/)

      PrimAmps(1)%ExtLine = (/1,5,2,3,4/)
      PrimAmps(2)%ExtLine = (/1,2,3,5,4/)
   ELSEIF( Correction.EQ.1 ) THEN
      BornAmps(1)%ExtLine = (/1,5,2,3,4/)
      BornAmps(2)%ExtLine = (/1,2,3,5,4/)

      PrimAmps(1)%ExtLine = (/1,5,2,3,4/)
      PrimAmp1_15234 = 1
      PrimAmps(1)%AmpType = 1

      PrimAmps(2)%ExtLine = (/1,2,3,5,4/)
      PrimAmp1_12354 = 2
      PrimAmps(2)%AmpType = 1

      PrimAmps(3)%ExtLine = (/1,5,2,4,3/)
      PrimAmp1_15243 = 3
      PrimAmps(3)%AmpType = 1

      PrimAmps(4)%ExtLine = (/1,2,4,5,3/)
      PrimAmp1_12453 = 4
      PrimAmps(4)%AmpType = 1

      PrimAmps(5)%ExtLine = (/1,5,4,3,2/)
      PrimAmp3_15432 = 5
      PrimAmps(5)%AmpType = 3

      PrimAmps(6)%ExtLine = (/1,4,5,3,2/)
      PrimAmp3_14532 = 6
      PrimAmps(6)%AmpType = 3

      PrimAmps(7)%ExtLine = (/1,4,3,5,2/)
      PrimAmp3_14352 = 7
      PrimAmps(7)%AmpType = 3

      PrimAmps(8)%ExtLine = (/1,5,2,3,4/)
      PrimAmp4_15234 = 8
      PrimAmps(8)%AmpType = 4

      PrimAmps(9)%ExtLine = (/1,2,5,3,4/)
      PrimAmp4_12534 = 9
      PrimAmps(9)%AmpType = 4

      PrimAmps(10)%ExtLine = (/1,2,3,4,5/)
      PrimAmp4_12345 = 10
      PrimAmps(10)%AmpType = 4



      PrimAmps(11)%ExtLine = (/1,5,2,3,4/)
      PrimAmp2_15234 = 11
      PrimAmps(11)%AmpType = 2
      PrimAmps(11)%FermLoopPart = Chm_

      PrimAmps(12)%ExtLine = (/1,2,3,5,4/)
      PrimAmp2_12354 = 12
      PrimAmps(12)%AmpType = 2
      PrimAmps(12)%FermLoopPart = Chm_

!       PrimAmps(13)%ExtLine = (/1,2,5,3,4/)
!       PrimAmp2_12534 = 13
!       PrimAmps(13)%AmpType = 2
!       PrimAmps(13)%FermLoopPart = Chm_
!
!       PrimAmps(14)%ExtLine = (/1,2,3,4,5/)
!       PrimAmp2_12345 = 14
!       PrimAmps(14)%AmpType = 2
!       PrimAmps(14)%FermLoopPart = Chm_


      PrimAmps(13)%ExtLine = (/1,5,2,3,4/)
      PrimAmp2m_15234 = 13
      PrimAmps(13)%AmpType = 2
      PrimAmps(13)%FermLoopPart = Bot_

      PrimAmps(14)%ExtLine = (/1,2,3,5,4/)
      PrimAmp2m_12354 = 14
      PrimAmps(14)%AmpType = 2
      PrimAmps(14)%FermLoopPart = Bot_

!       PrimAmps(17)%ExtLine = (/1,2,5,3,4/)
!       PrimAmp2m_12534 = 17
!       PrimAmps(17)%AmpType = 2
!       PrimAmps(17)%FermLoopPart = Bot_
!
!       PrimAmps(18)%ExtLine = (/1,2,3,4,5/)
!       PrimAmp2m_12345 = 18
!       PrimAmps(18)%AmpType = 2
!       PrimAmps(18)%FermLoopPart = Bot_

   ENDIF


ELSEIF( MasterProcess.EQ.10 ) THEN

   IF( Correction.EQ.2 ) THEN
      PrimAmps(1)%ExtLine = (/1,6,2,3,4,5/)
      BornAmps(1)%ExtLine = (/1,6,2,3,4,5/)

      PrimAmps(2)%ExtLine = (/1,6,2,3,5,4/)
      BornAmps(2)%ExtLine = (/1,6,2,3,5,4/)

      PrimAmps(3)%ExtLine = (/1,6,2,4,3,5/)
      BornAmps(3)%ExtLine = (/1,6,2,4,3,5/)

      PrimAmps(4)%ExtLine = (/1,6,2,4,5,3/)
      BornAmps(4)%ExtLine = (/1,6,2,4,5,3/)

      PrimAmps(5)%ExtLine = (/1,6,2,5,3,4/)
      BornAmps(5)%ExtLine = (/1,6,2,5,3,4/)

      PrimAmps(6)%ExtLine = (/1,6,2,5,4,3/)
      BornAmps(6)%ExtLine = (/1,6,2,5,4,3/)
   ENDIF



ELSEIF( MasterProcess.EQ.11 ) THEN

   IF( Correction.EQ.2 ) THEN
      PrimAmps( 1)%ExtLine = (/1,6,2,3,4,5/)
      BornAmps( 1)%ExtLine = (/1,6,2,3,4,5/)
      PrimAmp1_162345 = 1

      PrimAmps( 2)%ExtLine = (/1,2,3,6,4,5/)
      BornAmps( 2)%ExtLine = (/1,2,3,6,4,5/)
      PrimAmp1_123645 = 2

      PrimAmps( 3)%ExtLine = (/1,6,2,5,3,4/)
      BornAmps( 3)%ExtLine = (/1,6,2,5,3,4/)
      PrimAmp1_162534 = 3

      PrimAmps( 4)%ExtLine = (/1,2,5,3,6,4/)
      BornAmps( 4)%ExtLine = (/1,2,5,3,6,4/)
      PrimAmp1_125364 = 4

      PrimAmps( 5)%ExtLine = (/1,5,6,2,3,4/)
      BornAmps( 5)%ExtLine = (/1,5,6,2,3,4/)
      PrimAmp1_156234 = 5

      PrimAmps( 6)%ExtLine = (/1,6,5,2,3,4/)
      BornAmps( 6)%ExtLine = (/1,6,5,2,3,4/)
      PrimAmp1_165234 = 6

      PrimAmps( 7)%ExtLine = (/1,5,2,3,6,4/)
      BornAmps( 7)%ExtLine = (/1,5,2,3,6,4/)
      PrimAmp1_152364 = 7

      PrimAmps( 8)%ExtLine = (/1,6,2,3,5,4/)
      BornAmps( 8)%ExtLine = (/1,6,2,3,5,4/)
      PrimAmp1_162354 = 8

      PrimAmps( 9)%ExtLine = (/1,2,3,5,6,4/)
      BornAmps( 9)%ExtLine = (/1,2,3,5,6,4/)
      PrimAmp1_123564 = 9

      PrimAmps(10)%ExtLine = (/1,2,3,6,5,4/)
      BornAmps(10)%ExtLine = (/1,2,3,6,5,4/)
      PrimAmp1_123654 = 10
   ENDIF



ELSEIF( MASTERPROCESS.EQ.12 ) THEN

   IF( Correction.EQ.0 .OR. Correction.GE.4 ) THEN
      BornAmps(1)%ExtLine = (/1,2,3,4/)
      BornAmps(2)%ExtLine = (/1,2,4,3/)
      PrimAmps(1)%ExtLine = (/1,2,3,4/)
      PrimAmps(2)%ExtLine = (/1,2,4,3/)

!       BornAmps(1)%ExtLine = (/1,3,2,4/); print *, "for cross check"
!       PrimAmps(1)%ExtLine = (/1,3,2,4/)

!       BornAmps(1)%ExtLine = (/3,4,1,2/); print *, "for cross check"
!       PrimAmps(1)%ExtLine = BornAmps(1)%ExtLine


!       BornAmps(3)%ExtLine = (/3,4,1,2/); print *, "for crossed check"
!       BornAmps(4)%ExtLine = (/4,3,1,2/)
!       PrimAmps(3)%ExtLine = (/3,4,1,2/)
!       PrimAmps(4)%ExtLine = (/4,3,1,2/)

!       BornAmps(3)%ExtLine = (/3,2,1,4/); print *, "for crossed check"
!       BornAmps(4)%ExtLine = (/4,2,1,3/)
!       PrimAmps(3)%ExtLine = (/3,2,1,4/)
!       PrimAmps(4)%ExtLine = (/4,2,1,3/)

!       BornAmps(1)%ExtLine = (/1,4,3,2/)
!       BornAmps(2)%ExtLine = (/1,3,4,2/)
!       PrimAmps(1)%ExtLine = (/1,4,3,2/)
!       PrimAmps(2)%ExtLine = (/1,3,4,2/)

   ELSEIF ( Correction.EQ.1 ) THEN
      BornAmps(1)%ExtLine = (/1,2,3,4/)
      BornAmps(2)%ExtLine = (/1,2,4,3/)

      PrimAmps(1)%ExtLine = (/1,2,3,4/)
      PrimAmps(1)%AmpType = 1

      PrimAmps(2)%ExtLine = (/1,2,4,3/)
      PrimAmps(2)%AmpType = 1

      PrimAmps(3)%ExtLine = (/1,3,2,4/)
      PrimAmps(3)%AmpType = 1

      PrimAmps(4)%ExtLine = (/1,4,2,3/)
      PrimAmps(4)%AmpType = 1

      PrimAmps(5)%ExtLine = (/1,3,4,2/)
      PrimAmps(5)%AmpType = 1

      PrimAmps(6)%ExtLine = (/1,4,3,2/)
      PrimAmps(6)%AmpType = 1

      PrimAmps(7)%ExtLine = (/1,2,3,4/)
      PrimAmps(7)%AmpType = 2
      PrimAmps(7)%FermLoopPart = Chm_

      PrimAmps(8)%ExtLine = (/1,2,4,3/)
      PrimAmps(8)%AmpType = 2
      PrimAmps(8)%FermLoopPart = Chm_

      PrimAmps(9)%ExtLine = (/1,2,3,4/)
      PrimAmps(9)%AmpType = 2
      PrimAmps(9)%FermLoopPart = Bot_

      PrimAmps(10)%ExtLine = (/1,2,4,3/)
      PrimAmps(10)%AmpType = 2
      PrimAmps(10)%FermLoopPart = Bot_

      PrimAmps(11)%ExtLine = (/1,2,3,4/)
      PrimAmps(11)%AmpType = 2
      PrimAmps(11)%FermLoopPart = SBot_

      PrimAmps(12)%ExtLine = (/1,2,4,3/)
      PrimAmps(12)%AmpType = 2
      PrimAmps(12)%FermLoopPart = SBot_

   ENDIF





ELSEIF( MASTERPROCESS.EQ.13 ) THEN

   IF( Correction.EQ.0 .OR. Correction.GE.4 ) THEN
      BornAmps(1)%ExtLine = (/1,2,3,4/)
      PrimAmps(1)%ExtLine = (/1,2,3,4/)
!       BornAmps(2)%ExtLine = (/3,4,1,2/); print *, "for crossed check"
!       PrimAmps(2)%ExtLine = (/3,4,1,2/)


   ELSEIF( Correction.EQ.1 ) THEN 
        BornAmps(1)%ExtLine = (/1,2,3,4/)
        BornAmps(2)%ExtLine = (/1,2,4,3/)
        BornAmps(3)%ExtLine = (/1,2,3,4/)
        BornAmps(4)%ExtLine = (/1,2,3,4/)


        PrimAmps(1)%ExtLine = (/1,2,3,4/)
        PrimAmps(1)%AmpType = 1

        PrimAmps(2)%ExtLine = (/1,2,4,3/)
        PrimAmps(2)%AmpType = 1

        PrimAmps(3)%ExtLine = (/1,4,3,2/)
        PrimAmps(3)%AmpType = 3

        PrimAmps(4)%ExtLine = (/1,2,3,4/)
        PrimAmps(4)%AmpType = 4

        PrimAmps(5)%ExtLine = (/1,2,3,4/)
        PrimAmps(5)%AmpType = 2
        PrimAmps(5)%FermLoopPart = Chm_

        PrimAmps(6)%ExtLine = (/1,2,3,4/)
        PrimAmps(6)%AmpType = 2
        PrimAmps(6)%FermLoopPart = Bot_

        PrimAmps(7)%ExtLine = (/1,2,3,4/)
        PrimAmps(7)%AmpType = 2
        PrimAmps(7)%FermLoopPart = SBot_

        PrimAmp1_1234 = 1
        PrimAmp1_1243 = 2
        PrimAmp3_1432 = 3
        PrimAmp4_1234 = 4
        PrimAmp2_1234 = 5
        PrimAmp2m_1234 = 6

   ENDIF




ELSEIF( MASTERPROCESS.EQ.14 ) THEN

   IF( Correction.EQ.2 ) THEN
        BornAmps(1)%ExtLine = (/1,2,3,4,5/)
        BornAmps(2)%ExtLine = (/1,2,3,5,4/)
        BornAmps(3)%ExtLine = (/1,2,4,3,5/)
        BornAmps(4)%ExtLine = (/1,2,4,5,3/)
        BornAmps(5)%ExtLine = (/1,2,5,3,4/)
        BornAmps(6)%ExtLine = (/1,2,5,4,3/)

        PrimAmps(1)%ExtLine = (/1,2,3,4,5/)
        PrimAmps(2)%ExtLine = (/1,2,3,5,4/)
        PrimAmps(3)%ExtLine = (/1,2,4,3,5/)
        PrimAmps(4)%ExtLine = (/1,2,4,5,3/)
        PrimAmps(5)%ExtLine = (/1,2,5,3,4/)
        PrimAmps(6)%ExtLine = (/1,2,5,4,3/)
   ENDIF


ELSEIF( MASTERPROCESS.EQ.15 ) THEN

   IF( Correction.EQ.2 ) THEN
        PrimAmps(1)%ExtLine = (/1,2,3,4,5/)
        PrimAmps(2)%ExtLine = (/1,5,2,3,4/)
        PrimAmps(3)%ExtLine = (/1,2,5,3,4/)
        PrimAmps(4)%ExtLine = (/1,2,3,5,4/)

!         PrimAmps(1)%ExtLine = (/4,5,1,2,3/)
!         PrimAmps(2)%ExtLine = (/4,1,5,2,3/)
!         PrimAmps(3)%ExtLine = (/4,1,2,5,3/)
!         PrimAmps(4)%ExtLine = (/4,1,2,3,5/)


! check 1
!         PrimAmps(1)%ExtLine = (/1,2,3,4,5/)
!         PrimAmps(1)%ExtLine = (/4,5,1,2,3/)
!         PrimAmps(1)%ExtLine = (/5,1,2,3,4/)
!  res (4.700303546112113E-002,-0.274463149367225)
!  res (4.700303546111741E-002,-0.274463149367205)
!  res (4.700303546111741E-002,-0.274463149367205)



! check 2
!         PrimAmps(1)%ExtLine = (/1,3,4,2,5/)
!         PrimAmps(1)%ExtLine = (/3,4,2,5,1/)
!         PrimAmps(1)%ExtLine = (/5,1,3,4,2/)
!  res (-9.012782366790076E-003,0.106388279674873)
!  res (-9.012782366790081E-003,0.106388279674873)
!  res (-9.012782366790076E-003,0.106388279674873)


! check 3
!         PrimAmps(1)%ExtLine = (/4,1,2,5,3/)
!         PrimAmps(1)%ExtLine = (/3,4,1,2,5/)
!         PrimAmps(1)%ExtLine = (/2,5,3,4,1/)
!         PrimAmps(1)%ExtLine = (/1,2,5,3,4/)
!         PrimAmps(1)%ExtLine = (/5,3,4,1,2/)
!  res (4.705295763449123E-003,-5.019139065796818E-002)
!  res (4.705295763449118E-003,-5.019139065796809E-002)
!  res (4.705295763449123E-003,-5.019139065796817E-002)
!  res (4.705295763449121E-003,-5.019139065796813E-002)
!  res (4.705295763449118E-003,-5.019139065796811E-002)


   ENDIF



ELSEIF( MASTERPROCESS.EQ.16 ) THEN

   IF( Correction.EQ.0 ) THEN
!       BornAmps(1)%ExtLine = (/1,2,3,4,5,6/)
!       BornAmps(2)%ExtLine = (/2,3,4,5,6,1/)! this requires call to cur_s_sffsss_FERMLOOPCONTRIB
!  (3.553617730648898E-005,-4.248905967780229E-004)
!  (3.553617730648904E-005,-4.248905967780231E-004)
print *, "check this here"
      BornAmps(1)%ExtLine = (/6,1,2,3,4,5/)
      BornAmps(2)%ExtLine = (/2,3,4,5,6,1/)! this requires call to cur_s_sffsss
!  (2.484313163916796E-004,-5.444781253106519E-004)
!  (2.484313163916795E-004,-5.444781253106517E-004)

      PrimAmps(1)%ExtLine = BornAmps(1)%ExtLine
      PrimAmps(2)%ExtLine = BornAmps(2)%ExtLine



   ELSEIF( Correction.EQ.1 ) THEN

      BornAmps(1)%ExtLine = (/1,5,2,3,4/)
      PrimAmps(1)%ExtLine = BornAmps(1)%ExtLine
      PrimAmps(1)%AmpType = 1
   ENDIF




ELSEIF( MasterProcess.EQ.17 ) THEN! tb t g g Z0/Pho   ! ttb Z/Pho

   IF( Correction.EQ.0 .OR. Correction.EQ.4 .OR.Correction.EQ.5 ) THEN
      BornAmps(1)%ExtLine = (/1,5,2,3,4/)
      PrimAmps(1)%ExtLine = (/1,5,2,3,4/)

      BornAmps(2)%ExtLine = (/1,5,2,4,3/)
      PrimAmps(2)%ExtLine = (/1,5,2,4,3/)

   ELSEIF( Correction.EQ.1 ) THEN
      BornAmps(1)%ExtLine = (/1,5,2,3,4/)
      BornAmps(2)%ExtLine = (/1,5,2,4,3/)
      BornAmps(3)%ExtLine = (/1,3,5,2,4/)
      BornAmps(4)%ExtLine = (/1,5,3,2,4/)
      BornAmps(5)%ExtLine = (/1,4,5,2,3/)
      BornAmps(6)%ExtLine = (/1,5,4,2,3/)
      BornAmps(7)%ExtLine = (/1,5,3,4,2/)
      BornAmps(8)%ExtLine = (/1,3,5,4,2/)
      BornAmps(9)%ExtLine = (/1,3,4,5,2/)
      BornAmps(10)%ExtLine = (/1,5,4,3,2/)
      BornAmps(11)%ExtLine = (/1,4,5,3,2/)
      BornAmps(12)%ExtLine = (/1,4,3,5,2/)
      
      BornAmps(13)%ExtLine = (/1,5,3,4,2/)
      BornAmps(14)%ExtLine = (/1,3,5,4,2/)
      BornAmps(15)%ExtLine = (/1,3,4,5,2/)

      BornAmps(16)%ExtLine = (/1,5,4,3,2/)
      BornAmps(17)%ExtLine = (/1,4,5,3,2/)
      BornAmps(18)%ExtLine = (/1,4,3,5,2/)

      BornAmps(19)%ExtLine = (/1,3,4,5,2/)
      BornAmps(20)%ExtLine = (/1,4,3,5,2/)

      PrimAmps(1)%ExtLine = (/1,5,2,3,4/)
      PrimAmps(1)%AmpType = 1
      PrimAmps(1)%NumSisters = 0
      PrimAmp1_15234=1

      PrimAmps(2)%ExtLine = (/1,5,2,4,3/)
      PrimAmps(2)%AmpType = 1
      PrimAmps(2)%NumSisters = 0
      PrimAmp1_15243=2

      PrimAmps(3)%ExtLine = (/1,3,5,2,4/)
      PrimAmps(3)%AmpType = 1
      PrimAmps(3)%NumSisters = 1
      PrimAmp1_13524=3
      allocate( PrimAmps(3)%Sisters(1:PrimAmps(3)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(3)%Sisters(1) = 4

      PrimAmps(4)%ExtLine = (/1,5,3,2,4/)
      PrimAmps(4)%AmpType = 1
      PrimAmps(4)%NumSisters = 1
      allocate( PrimAmps(4)%Sisters(1:PrimAmps(4)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(4)%Sisters(1) = 3

      PrimAmps(5)%ExtLine = (/1,4,5,2,3/)
      PrimAmps(5)%AmpType = 1
      PrimAmps(5)%NumSisters = 1
      PrimAmp1_14523=5
      allocate( PrimAmps(5)%Sisters(1:PrimAmps(5)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(5)%Sisters(1) = 6

      PrimAmps(6)%ExtLine = (/1,5,4,2,3/)
      PrimAmps(6)%AmpType = 1
      PrimAmps(6)%NumSisters = 1
      allocate( PrimAmps(6)%Sisters(1:PrimAmps(6)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(6)%Sisters(1) = 5

      PrimAmps(7)%ExtLine = (/1,5,3,4,2/)
      PrimAmps(7)%AmpType = 1
      PrimAmps(7)%NumSisters = 2
      PrimAmp1_15342=7
      allocate( PrimAmps(7)%Sisters(1:PrimAmps(7)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(7)%Sisters(1) = 8
      PrimAmps(7)%Sisters(2) = 9

      PrimAmps(8)%ExtLine = (/1,3,5,4,2/)
      PrimAmps(8)%AmpType = 1
      PrimAmps(8)%NumSisters = 2
      allocate( PrimAmps(8)%Sisters(1:PrimAmps(8)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(8)%Sisters(1) = 7
      PrimAmps(8)%Sisters(2) = 9

      PrimAmps(9)%ExtLine = (/1,3,4,5,2/)
      PrimAmps(9)%AmpType = 1
      PrimAmps(9)%NumSisters = 2
      allocate( PrimAmps(9)%Sisters(1:PrimAmps(9)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(9)%Sisters(1) = 7
      PrimAmps(9)%Sisters(2) = 8

      PrimAmps(10)%ExtLine = (/1,5,4,3,2/)
      PrimAmps(10)%AmpType = 1
      PrimAmps(10)%NumSisters = 2
      PrimAmp1_15432=10
      allocate( PrimAmps(10)%Sisters(1:PrimAmps(10)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(10)%Sisters(1) = 11
      PrimAmps(10)%Sisters(2) = 12

      PrimAmps(11)%ExtLine = (/1,4,5,3,2/)
      PrimAmps(11)%AmpType = 1
      PrimAmps(11)%NumSisters = 2
      allocate( PrimAmps(11)%Sisters(1:PrimAmps(11)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(11)%Sisters(1) = 10
      PrimAmps(11)%Sisters(2) = 12

      PrimAmps(12)%ExtLine = (/1,4,3,5,2/)
      PrimAmps(12)%AmpType = 1
      PrimAmps(12)%NumSisters = 2
      allocate( PrimAmps(12)%Sisters(1:PrimAmps(12)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(12)%Sisters(1) = 10
      PrimAmps(12)%Sisters(2) = 11

! ferm loops begin here

      PrimAmps(13)%ExtLine=(/1,2,5,3,4/)
      PrimAmps(13)%AmpType=2
      PrimAmps(13)%NumSisters=2
      PrimAmps(13)%FermLoopPart=Chm_
      PrimAmp2_12534=13
      allocate( PrimAmps(13)%Sisters(1:PrimAmps(13)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(13)%Sisters(1) = 14
      PrimAmps(13)%Sisters(2) = 15

      PrimAmps(14)%ExtLine=(/1,2,3,5,4/)
      PrimAmps(14)%AmpType=2
      PrimAmps(14)%NumSisters=2
      PrimAmps(14)%FermLoopPart=Chm_
      PrimAmp2_12354=14
      allocate( PrimAmps(14)%Sisters(1:PrimAmps(14)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(14)%Sisters(1) = 13
      PrimAmps(14)%Sisters(2) = 15

      PrimAmps(15)%ExtLine=(/1,2,3,4,5/)
      PrimAmps(15)%AmpType=2
      PrimAmps(15)%NumSisters=2
      PrimAmps(15)%FermLoopPart=Chm_
      PrimAmp2_12345=15
      allocate( PrimAmps(15)%Sisters(1:PrimAmps(15)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(15)%Sisters(1) = 13
      PrimAmps(15)%Sisters(2) = 14

      PrimAmps(16)%ExtLine=(/1,2,5,4,3/)
      PrimAmps(16)%AmpType=2
      PrimAmps(16)%NumSisters=2
      PrimAmps(16)%FermLoopPart=Chm_
      PrimAmp2_12543=16
      allocate( PrimAmps(16)%Sisters(1:PrimAmps(16)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(16)%Sisters(1) = 17
      PrimAmps(16)%Sisters(2) = 18

      PrimAmps(17)%ExtLine=(/1,2,4,5,3/)
      PrimAmps(17)%AmpType=2
      PrimAmps(17)%NumSisters=2
      PrimAmps(17)%FermLoopPart=Chm_
      PrimAmp2_12453=17
      allocate( PrimAmps(17)%Sisters(1:PrimAmps(17)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(17)%Sisters(1) = 16
      PrimAmps(17)%Sisters(2) = 18

      PrimAmps(18)%ExtLine=(/1,2,4,3,5/)
      PrimAmps(18)%AmpType=2
      PrimAmps(18)%NumSisters=2
      PrimAmps(18)%FermLoopPart=Chm_
      PrimAmp2_12435=18
      allocate( PrimAmps(18)%Sisters(1:PrimAmps(18)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(18)%Sisters(1) = 16
      PrimAmps(18)%Sisters(2) = 17


      PrimAmps(19)%ExtLine=(/1,5,2,3,4/)
      PrimAmps(19)%AmpType=2
      PrimAmps(19)%NumSisters=0
      PrimAmps(19)%FermLoopPart=Chm_
      PrimAmp2_15234=19
      allocate( PrimAmps(19)%Sisters(1:PrimAmps(19)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")


      PrimAmps(20)%ExtLine=(/1,5,2,4,3/)
      PrimAmps(20)%AmpType=2
      PrimAmps(20)%NumSisters=0
      PrimAmps(20)%FermLoopPart=Chm_
      PrimAmp2_15243=20
      allocate( PrimAmps(20)%Sisters(1:PrimAmps(20)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")


!! RR added 1 March 2014 -- massless subleading color quark loops


      PrimAmps(29)%ExtLine=(/1,3,2,5,4/)
      PrimAmps(29)%AmpType=2
      PrimAmps(29)%NumSisters=1
      PrimAmps(29)%FermLoopPart=Chm_
      PrimAmp2_13254=29
      allocate( PrimAmps(29)%Sisters(1:PrimAmps(29)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(29)%Sisters(1) =30

      PrimAmps(30)%ExtLine=(/1,3,2,4,5/)
      PrimAmps(30)%AmpType=2
      PrimAmps(30)%NumSisters=1
      PrimAmps(30)%FermLoopPart=Chm_
      PrimAmp2_13245=30
      allocate( PrimAmps(30)%Sisters(1:PrimAmps(30)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(30)%Sisters(1) = 29


      PrimAmps(31)%ExtLine=(/1,4,2,5,3/)
      PrimAmps(31)%AmpType=2
      PrimAmps(31)%NumSisters=1
      PrimAmps(31)%FermLoopPart=Chm_
      PrimAmp2_14253=31
      allocate( PrimAmps(31)%Sisters(1:PrimAmps(31)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(31)%Sisters(1) = 32


      PrimAmps(32)%ExtLine=(/1,4,2,3,5/)
      PrimAmps(32)%AmpType=2
      PrimAmps(32)%NumSisters=1
      PrimAmps(32)%FermLoopPart=Chm_
      PrimAmp2_14235=32
      allocate( PrimAmps(32)%Sisters(1:PrimAmps(32)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(32)%Sisters(1) = 31


! massive ferm loops
      PrimAmps(21)%ExtLine=(/1,2,5,3,4/)
      PrimAmps(21)%AmpType=2
      PrimAmps(21)%NumSisters=2
      PrimAmps(21)%FermLoopPart=Bot_
      PrimAmp2m_12534=21
      allocate( PrimAmps(21)%Sisters(1:PrimAmps(21)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(21)%Sisters(1) = 22
      PrimAmps(21)%Sisters(2) = 23

      PrimAmps(22)%ExtLine=(/1,2,3,5,4/)
      PrimAmps(22)%AmpType=2
      PrimAmps(22)%NumSisters=2
      PrimAmps(22)%FermLoopPart=Bot_
      PrimAmp2m_12354=22
      allocate( PrimAmps(22)%Sisters(1:PrimAmps(22)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(22)%Sisters(1) = 21
      PrimAmps(22)%Sisters(2) = 23

      PrimAmps(23)%ExtLine=(/1,2,3,4,5/)
      PrimAmps(23)%AmpType=2
      PrimAmps(23)%NumSisters=2
      PrimAmps(23)%FermLoopPart=Bot_
      PrimAmp2m_12345=23
      allocate( PrimAmps(23)%Sisters(1:PrimAmps(23)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(23)%Sisters(1) = 21
      PrimAmps(23)%Sisters(2) = 22

      PrimAmps(24)%ExtLine=(/1,2,5,4,3/)
      PrimAmps(24)%AmpType=2
      PrimAmps(24)%NumSisters=2
      PrimAmps(24)%FermLoopPart=Bot_
      PrimAmp2m_12543=24
      allocate( PrimAmps(24)%Sisters(1:PrimAmps(24)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(24)%Sisters(1) = 25
      PrimAmps(24)%Sisters(2) = 26

      PrimAmps(25)%ExtLine=(/1,2,4,5,3/)
      PrimAmps(25)%AmpType=2
      PrimAmps(25)%NumSisters=2
      PrimAmps(25)%FermLoopPart=Bot_
      PrimAmp2m_12453=25
      allocate( PrimAmps(25)%Sisters(1:PrimAmps(25)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(25)%Sisters(1) = 24
      PrimAmps(25)%Sisters(2) = 26

      PrimAmps(26)%ExtLine=(/1,2,4,3,5/)
      PrimAmps(26)%AmpType=2
      PrimAmps(26)%NumSisters=2
      PrimAmps(26)%FermLoopPart=Bot_
      PrimAmp2m_12435=26
      allocate( PrimAmps(26)%Sisters(1:PrimAmps(26)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(26)%Sisters(1) = 24
      PrimAmps(26)%Sisters(2) = 25


      PrimAmps(27)%ExtLine=(/1,5,2,3,4/)
      PrimAmps(27)%AmpType=2
      PrimAmps(27)%NumSisters=0
      PrimAmps(27)%FermLoopPart=Bot_
      PrimAmp2m_15234=27
      allocate( PrimAmps(27)%Sisters(1:PrimAmps(27)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")


      PrimAmps(28)%ExtLine=(/1,5,2,4,3/)
      PrimAmps(28)%AmpType=2
      PrimAmps(28)%NumSisters=0
      PrimAmps(28)%FermLoopPart=Bot_
      PrimAmp2m_15243=28
      allocate( PrimAmps(28)%Sisters(1:PrimAmps(28)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")


!! RR added 1 March 2014 -- massive subleading color quark loops

      PrimAmps(33)%ExtLine=(/1,3,2,5,4/)
      PrimAmps(33)%AmpType=2
      PrimAmps(33)%NumSisters=1
      PrimAmps(33)%FermLoopPart=Bot_
      PrimAmp2m_13254=33
      allocate( PrimAmps(33)%Sisters(1:PrimAmps(33)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(33)%Sisters(1) =34

      PrimAmps(34)%ExtLine=(/1,3,2,4,5/)
      PrimAmps(34)%AmpType=2
      PrimAmps(34)%NumSisters=1
      PrimAmps(34)%FermLoopPart=Bot_
      PrimAmp2m_13245=34
      allocate( PrimAmps(34)%Sisters(1:PrimAmps(34)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(34)%Sisters(1) = 33


      PrimAmps(35)%ExtLine=(/1,4,2,5,3/)
      PrimAmps(35)%AmpType=2
      PrimAmps(35)%NumSisters=1
      PrimAmps(35)%FermLoopPart=Bot_
      PrimAmp2m_14253=35
      allocate( PrimAmps(35)%Sisters(1:PrimAmps(35)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(35)%Sisters(1) = 36


      PrimAmps(36)%ExtLine=(/1,4,2,3,5/)
      PrimAmps(36)%AmpType=2
      PrimAmps(36)%NumSisters=1
      PrimAmps(36)%FermLoopPart=Bot_
      PrimAmp2m_14235=36
      allocate( PrimAmps(36)%Sisters(1:PrimAmps(36)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
      PrimAmps(36)%Sisters(1) = 35







!       PrimAmps(16)%ExtLine=(/1,5,3,4,2/)        ! M: ??
!       PrimAmps(16)%AmpType=2
!       PrimAmps(16)%NumSisters=2
!       PrimAmps(16)%FermLoopPart=Up_
!       allocate( PrimAmps(16)%Sisters(1:PrimAmps(16)%NumSisters), stat=AllocStatus )
!       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
!       PrimAmps(16)%Sisters(1) = 17
!       PrimAmps(16)%Sisters(2) = 18

!       PrimAmps(17)%ExtLine=(/1,3,5,4,2/)        ! M: ??
!       PrimAmps(17)%AmpType=2
!       PrimAmps(17)%NumSisters=2
!       PrimAmps(17)%FermLoopPart=Up_
!       allocate( PrimAmps(17)%Sisters(1:PrimAmps(17)%NumSisters), stat=AllocStatus )
!       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
!       PrimAmps(17)%Sisters(1) = 16
!       PrimAmps(17)%Sisters(2) = 18

!       PrimAmps(18)%ExtLine=(/1,3,4,5,2/)        ! M: ??
!       PrimAmps(18)%AmpType=2
!       PrimAmps(18)%NumSisters=2
!       PrimAmps(18)%FermLoopPart=Up_
!       allocate( PrimAmps(18)%Sisters(1:PrimAmps(18)%NumSisters), stat=AllocStatus )
!       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
!       PrimAmps(18)%Sisters(1) = 16
!       PrimAmps(18)%Sisters(2) = 17

! for the time being, I'm ignoring ferm loop prims
!      call Error("need more work here:MasterProcess.EQ.17 ")
!       print *, 'WARNING: FERMION LOOPS NOT INCLUDED'
!      call Error("need more work here:MasterProcess.EQ.17 ")

   ENDIF


ELSEIF( MASTERPROCESS.EQ.18 ) THEN! tb t qb q Z0/Pho  ! ttbZ/Pho

   IF( Correction.EQ.0  .OR. Correction.EQ.4 .OR.Correction.EQ.5 ) THEN
      BornAmps(1)%ExtLine = (/1,5,2,3,4/)!  Z coupling to top quark line
      BornAmps(2)%ExtLine = (/1,2,3,5,4/)!  Z coupling to massless quark line

      PrimAmps(1)%ExtLine = (/1,5,2,3,4/)
      PrimAmps(2)%ExtLine = (/1,2,3,5,4/)
   ELSEIF( Correction.EQ.1 ) THEN

      BornAmps(1)%ExtLine = (/1,5,2,3,4/)
      BornAmps(2)%ExtLine = (/1,2,3,5,4/)
      BornAmps(3)%ExtLine = (/1,5,2,3,4/)
      BornAmps(4)%ExtLine = (/1,2,3,5,4/)
      BornAmps(5)%ExtLine = (/1,5,4,3,2/)
      BornAmps(6)%ExtLine = (/1,4,3,5,2/)
! note that BornAmps 7 and 8 both give the same as 2, so use only one of these when looking at (virtual) primitive 7+8...
      BornAmps(7)%ExtLine = (/1,2,3,5,4/)
      BornAmps(8)%ExtLine = (/1,2,3,5,4/)
      BornAmps(9)%ExtLine = (/1,4,5,3,2/)
      BornAmps(10)%ExtLine = (/1,5,2,3,4/)

      PrimAmps(1)%ExtLine = (/1,5,2,3,4/)
      PrimAmps(1)%AmpType = 1
      PrimAmps(1)%NumSisters = 0
      PrimAmp1_15234=1
      allocate( PrimAmps(1)%Sisters(1:PrimAmps(1)%NumSisters), stat=AllocStatus )      
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")

      PrimAmps(2)%ExtLine = (/1,2,3,5,4/)
      PrimAmps(2)%AmpType = 1
      PrimAmps(2)%NumSisters = 0
      PrimAmp1_12354=2
      allocate( PrimAmps(2)%Sisters(1:PrimAmps(2)%NumSisters), stat=AllocStatus )
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")

      PrimAmps(3)%ExtLine = (/1,5,2,4,3/)
      PrimAmp1_15243 = 3
      PrimAmps(3)%AmpType = 1
      PrimAmps(3)%NumSisters = 0
      allocate( PrimAmps(3)%Sisters(1:PrimAmps(3)%NumSisters), stat=AllocStatus )      
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")

      PrimAmps(4)%ExtLine = (/1,2,4,5,3/)
      PrimAmp1_12453 = 4
      PrimAmps(4)%AmpType = 1
      PrimAmps(4)%NumSisters = 0
      allocate( PrimAmps(4)%Sisters(1:PrimAmps(4)%NumSisters), stat=AllocStatus )      
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")

      PrimAmps(5)%ExtLine = (/1,5,4,3,2/)
      PrimAmp3_15432 = 5
      PrimAmps(5)%AmpType = 3
      PrimAmps(5)%NumSisters = 0
      allocate( PrimAmps(5)%Sisters(1:PrimAmps(5)%NumSisters), stat=AllocStatus )      
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")

      PrimAmps(6)%ExtLine = (/1,4,3,5,2/)! MARKUS: new primamp with Z on bottom
      PrimAmp3_14352 = 6
      PrimAmps(6)%AmpType = 3
      PrimAmps(6)%NumSisters = 0
      allocate( PrimAmps(6)%Sisters(1:PrimAmps(6)%NumSisters), stat=AllocStatus )      
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")

      PrimAmps(7)%ExtLine = (/1,2,5,3,4/)
      PrimAmp4_12534 = 7
      PrimAmps(7)%AmpType = 4
      PrimAmps(7)%NumSisters = 0
      allocate( PrimAmps(7)%Sisters(1:PrimAmps(7)%NumSisters), stat=AllocStatus )      
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")

      PrimAmps(8)%ExtLine = (/1,2,3,4,5/) ! MARKUS: new primamp with Z on bottom
      PrimAmp4_12345 = 8
      PrimAmps(8)%AmpType = 4
      PrimAmps(8)%NumSisters = 0
      allocate( PrimAmps(8)%Sisters(1:PrimAmps(8)%NumSisters), stat=AllocStatus )      
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")

      PrimAmps(9)%ExtLine = (/1,4,5,3,2/)
      PrimAmp3_14532 = 9
      PrimAmps(9)%AmpType = 3
      PrimAmps(9)%NumSisters = 0
      allocate( PrimAmps(9)%Sisters(1:PrimAmps(9)%NumSisters), stat=AllocStatus )      
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")

      PrimAmps(10)%ExtLine = (/1,5,2,3,4/)
      PrimAmp4_15234 = 10
      PrimAmps(10)%AmpType = 4
      PrimAmps(10)%NumSisters = 0
      allocate( PrimAmps(10)%Sisters(1:PrimAmps(10)%NumSisters), stat=AllocStatus )      
      if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")


! ferm loops begin here    
      PrimAmps(11)%ExtLine=(/1,2,5,3,4/)
      PrimAmps(11)%AmpType=2
      PrimAmps(11)%NumSisters=0
      PrimAmps(11)%FermLoopPart=Chm_
      PrimAmp2_12534=11
      allocate( PrimAmps(11)%Sisters(1:PrimAmps(11)%NumSisters), stat=AllocStatus )

      PrimAmps(12)%ExtLine=(/1,2,3,4,5/)
      PrimAmps(12)%AmpType=2
      PrimAmps(12)%NumSisters=0
      PrimAmps(12)%FermLoopPart=Chm_
      PrimAmp2_12345=12
      allocate( PrimAmps(12)%Sisters(1:PrimAmps(12)%NumSisters), stat=AllocStatus )

      PrimAmps(13)%ExtLine=(/1,2,5,3,4/)
      PrimAmps(13)%AmpType=2
      PrimAmps(13)%NumSisters=0
      PrimAmps(13)%FermLoopPart=Bot_
      PrimAmp2m_12534=13
      allocate( PrimAmps(13)%Sisters(1:PrimAmps(13)%NumSisters), stat=AllocStatus )

      PrimAmps(14)%ExtLine=(/1,2,3,4,5/)
      PrimAmps(14)%AmpType=2
      PrimAmps(14)%NumSisters=0
      PrimAmps(14)%FermLoopPart=Bot_
      PrimAmp2m_12345=14
      allocate( PrimAmps(14)%Sisters(1:PrimAmps(14)%NumSisters), stat=AllocStatus )  

      PrimAmps(15)%ExtLine=(/1,5,2,3,4/)
      PrimAmps(15)%AmpType=2
      PrimAmps(15)%NumSisters=0
      PrimAmps(15)%FermLoopPart=Chm_
      PrimAmp2_15234=15
      allocate( PrimAmps(15)%Sisters(1:PrimAmps(15)%NumSisters), stat=AllocStatus )

      PrimAmps(16)%ExtLine=(/1,5,2,3,4/)
      PrimAmps(16)%AmpType=2
      PrimAmps(16)%NumSisters=0
      PrimAmps(16)%FermLoopPart=Bot_
      PrimAmp2m_15234=16
      allocate( PrimAmps(16)%Sisters(1:PrimAmps(16)%NumSisters), stat=AllocStatus )

      PrimAmps(17)%ExtLine=(/1,2,3,5,4/)
      PrimAmps(17)%AmpType=2
      PrimAmps(17)%NumSisters=0
      PrimAmps(17)%FermLoopPart=Chm_
      PrimAmp2_12354=17
      allocate( PrimAmps(17)%Sisters(1:PrimAmps(17)%NumSisters), stat=AllocStatus )

      PrimAmps(18)%ExtLine=(/1,2,3,5,4/)
      PrimAmps(18)%AmpType=2
      PrimAmps(18)%NumSisters=0
      PrimAmps(18)%FermLoopPart=Bot_
      PrimAmp2m_12354=18
      allocate( PrimAmps(18)%Sisters(1:PrimAmps(18)%NumSisters), stat=AllocStatus )

   ENDIF



ELSEIF( MasterProcess.EQ.19 ) THEN

   IF( Correction.EQ.2 ) THEN
      PrimAmps(1)%ExtLine = (/1,6,2,3,4,5/)
      BornAmps(1)%ExtLine = (/1,6,2,3,4,5/)

      PrimAmps(2)%ExtLine = (/1,6,2,3,5,4/)
      BornAmps(2)%ExtLine = (/1,6,2,3,5,4/)

      PrimAmps(3)%ExtLine = (/1,6,2,4,3,5/)
      BornAmps(3)%ExtLine = (/1,6,2,4,3,5/)

      PrimAmps(4)%ExtLine = (/1,6,2,4,5,3/)
      BornAmps(4)%ExtLine = (/1,6,2,4,5,3/)

      PrimAmps(5)%ExtLine = (/1,6,2,5,3,4/)
      BornAmps(5)%ExtLine = (/1,6,2,5,3,4/)

      PrimAmps(6)%ExtLine = (/1,6,2,5,4,3/)
      BornAmps(6)%ExtLine = (/1,6,2,5,4,3/)


      if( TTBZ_SpeedUp ) then
            PrimAmps(1)%ExtLine = (/3,4,5,1,6,2/)
            BornAmps(1)%ExtLine = (/3,4,5,1,6,2/)

            PrimAmps(2)%ExtLine = (/3,5,4,1,6,2/)
            BornAmps(2)%ExtLine = (/3,5,4,1,6,2/)

            PrimAmps(3)%ExtLine = (/3,5,1,6,2,4/)
            BornAmps(3)%ExtLine = (/3,5,1,6,2,4/)

            PrimAmps(4)%ExtLine = (/3,1,6,2,4,5/)
            BornAmps(4)%ExtLine = (/3,1,6,2,4,5/)

            PrimAmps(5)%ExtLine = (/3,4,1,6,2,5/)
            BornAmps(5)%ExtLine = (/3,4,1,6,2,5/)

            PrimAmps(6)%ExtLine = (/3,1,6,2,5,4/)
            BornAmps(6)%ExtLine = (/3,1,6,2,5,4/)
      endif


   ENDIF



ELSEIF( MasterProcess.EQ.20 ) THEN

   IF( Correction.EQ.2 ) THEN
      PrimAmps( 1)%ExtLine = (/1,6,2,3,4,5/)
      BornAmps( 1)%ExtLine = (/1,6,2,3,4,5/)
      PrimAmp1_162345 = 1

      PrimAmps( 2)%ExtLine = (/1,2,3,6,4,5/)
      BornAmps( 2)%ExtLine = (/1,2,3,6,4,5/)
      PrimAmp1_123645 = 2

      PrimAmps( 3)%ExtLine = (/1,6,2,5,3,4/)
      BornAmps( 3)%ExtLine = (/1,6,2,5,3,4/)
      PrimAmp1_162534 = 3

      PrimAmps( 4)%ExtLine = (/1,2,5,3,6,4/)
      BornAmps( 4)%ExtLine = (/1,2,5,3,6,4/)
      PrimAmp1_125364 = 4

      PrimAmps( 5)%ExtLine = (/1,6,5,2,3,4/)
      BornAmps( 5)%ExtLine = (/1,6,5,2,3,4/)
      PrimAmp1_165234 = 5

      PrimAmps( 6)%ExtLine = (/1,5,2,3,6,4/)
      BornAmps( 6)%ExtLine = (/1,5,2,3,6,4/)
      PrimAmp1_152364 = 6

      PrimAmps( 7)%ExtLine = (/1,6,2,3,5,4/)
      BornAmps( 7)%ExtLine = (/1,6,2,3,5,4/)
      PrimAmp1_162354 = 7

      PrimAmps(8)%ExtLine = (/1,2,3,6,5,4/)
      BornAmps(8)%ExtLine = (/1,2,3,6,5,4/)
      PrimAmp1_123654 = 8
   ENDIF

   
   


ELSEIF( MasterProcess.EQ.21) THEN


ELSEIF( MasterProcess.EQ.22) THEN



ELSEIF( MasterProcess.EQ.23 ) THEN! tb t g g Higgs    !ttbH

   IF( Correction.EQ.0 .OR. Correction.EQ.4 .OR.Correction.EQ.5 ) THEN
      BornAmps(1)%ExtLine = (/1,5,2,3,4/)
      PrimAmps(1)%ExtLine = (/1,5,2,3,4/)

      BornAmps(2)%ExtLine = (/1,5,2,4,3/)
      PrimAmps(2)%ExtLine = (/1,5,2,4,3/)

   ELSEIF( Correction.EQ.1 ) THEN
       BornAmps(1)%ExtLine = (/1,5,2,3,4/)
       BornAmps(2)%ExtLine = (/1,5,2,4,3/)
       BornAmps(3)%ExtLine = (/1,3,5,2,4/)
       BornAmps(4)%ExtLine = (/1,5,3,2,4/)
       BornAmps(5)%ExtLine = (/1,4,5,2,3/)
       BornAmps(6)%ExtLine = (/1,5,4,2,3/)
       BornAmps(7)%ExtLine = (/1,5,3,4,2/)
       BornAmps(8)%ExtLine = (/1,3,5,4,2/)
       BornAmps(9)%ExtLine = (/1,3,4,5,2/)
       BornAmps(10)%ExtLine = (/1,5,4,3,2/)
       BornAmps(11)%ExtLine = (/1,4,5,3,2/)
       BornAmps(12)%ExtLine = (/1,4,3,5,2/)     

       BornAmps(13)%ExtLine = (/1,3,4,5,2/)
       BornAmps(14)%ExtLine = (/1,4,3,5,2/)
       BornAmps(15)%ExtLine = (/1,5,3,4,2/)
       BornAmps(16)%ExtLine = (/1,3,5,4,2/)
       BornAmps(17)%ExtLine = (/1,3,4,5,2/)
       BornAmps(18)%ExtLine = (/1,5,4,3,2/)
       BornAmps(19)%ExtLine = (/1,4,5,3,2/)
       BornAmps(20)%ExtLine = (/1,4,3,5,2/)
       BornAmps(21)%ExtLine = (/1,3,4,5,2/)
       BornAmps(22)%ExtLine = (/1,4,3,5,2/) 
       BornAmps(23)%ExtLine = (/1,3,2,5,4/)
       BornAmps(24)%ExtLine = (/1,3,2,4,5/)
       BornAmps(25)%ExtLine = (/1,4,2,5,3/)
       BornAmps(26)%ExtLine = (/1,4,2,3,5/)

! 
       PrimAmps(1)%ExtLine = (/1,5,2,3,4/)
       PrimAmps(1)%AmpType = 1
       PrimAmps(1)%NumSisters = 0
       PrimAmp1_15234=1
 
       PrimAmps(2)%ExtLine = (/1,5,2,4,3/)
       PrimAmps(2)%AmpType = 1
       PrimAmps(2)%NumSisters = 0
       PrimAmp1_15243=2
 
       PrimAmps(3)%ExtLine = (/1,3,5,2,4/)
       PrimAmps(3)%AmpType = 1
       PrimAmps(3)%NumSisters = 1
       PrimAmp1_13524=3
       allocate( PrimAmps(3)%Sisters(1:PrimAmps(3)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
       PrimAmps(3)%Sisters(1) = 4
 
       PrimAmps(4)%ExtLine = (/1,5,3,2,4/)
       PrimAmps(4)%AmpType = 1
       PrimAmps(4)%NumSisters = 1
       allocate( PrimAmps(4)%Sisters(1:PrimAmps(4)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
       PrimAmps(4)%Sisters(1) = 3
 
       PrimAmps(5)%ExtLine = (/1,4,5,2,3/)
       PrimAmps(5)%AmpType = 1
       PrimAmps(5)%NumSisters = 1
       PrimAmp1_14523=5
       allocate( PrimAmps(5)%Sisters(1:PrimAmps(5)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
       PrimAmps(5)%Sisters(1) = 6
 
       PrimAmps(6)%ExtLine = (/1,5,4,2,3/)
       PrimAmps(6)%AmpType = 1
       PrimAmps(6)%NumSisters = 1
       allocate( PrimAmps(6)%Sisters(1:PrimAmps(6)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
       PrimAmps(6)%Sisters(1) = 5
 
       PrimAmps(7)%ExtLine = (/1,5,3,4,2/)
       PrimAmps(7)%AmpType = 1
       PrimAmps(7)%NumSisters = 2
       PrimAmp1_15342=7
       allocate( PrimAmps(7)%Sisters(1:PrimAmps(7)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
       PrimAmps(7)%Sisters(1) = 8
       PrimAmps(7)%Sisters(2) = 9
 
       PrimAmps(8)%ExtLine = (/1,3,5,4,2/)
       PrimAmps(8)%AmpType = 1
       PrimAmps(8)%NumSisters = 2
       allocate( PrimAmps(8)%Sisters(1:PrimAmps(8)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
       PrimAmps(8)%Sisters(1) = 7
       PrimAmps(8)%Sisters(2) = 9
 
       PrimAmps(9)%ExtLine = (/1,3,4,5,2/)
       PrimAmps(9)%AmpType = 1
       PrimAmps(9)%NumSisters = 2
       allocate( PrimAmps(9)%Sisters(1:PrimAmps(9)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
       PrimAmps(9)%Sisters(1) = 7
       PrimAmps(9)%Sisters(2) = 8
 
       PrimAmps(10)%ExtLine = (/1,5,4,3,2/)
       PrimAmps(10)%AmpType = 1
       PrimAmps(10)%NumSisters = 2
       PrimAmp1_15432=10
       allocate( PrimAmps(10)%Sisters(1:PrimAmps(10)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
       PrimAmps(10)%Sisters(1) = 11
       PrimAmps(10)%Sisters(2) = 12
 
       PrimAmps(11)%ExtLine = (/1,4,5,3,2/)
       PrimAmps(11)%AmpType = 1
       PrimAmps(11)%NumSisters = 2
       allocate( PrimAmps(11)%Sisters(1:PrimAmps(11)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
       PrimAmps(11)%Sisters(1) = 10
       PrimAmps(11)%Sisters(2) = 12
 
       PrimAmps(12)%ExtLine = (/1,4,3,5,2/)
       PrimAmps(12)%AmpType = 1
       PrimAmps(12)%NumSisters = 2
       allocate( PrimAmps(12)%Sisters(1:PrimAmps(12)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
       PrimAmps(12)%Sisters(1) = 10
       PrimAmps(12)%Sisters(2) = 11
 
! ! massless ferm loops -- Higgs attached to ext tops
 
       PrimAmps(13)%ExtLine=(/1,5,2,3,4/)
       PrimAmps(13)%AmpType=2
       PrimAmps(13)%NumSisters=0
       PrimAmps(13)%FermLoopPart=Chm_
       PrimAmp2_15234=13
       allocate( PrimAmps(13)%Sisters(1:PrimAmps(13)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
 
 
       PrimAmps(14)%ExtLine=(/1,5,2,4,3/)
       PrimAmps(14)%AmpType=2
       PrimAmps(14)%NumSisters=0
       PrimAmps(14)%FermLoopPart=Chm_
       PrimAmp2_15243=14
       allocate( PrimAmps(14)%Sisters(1:PrimAmps(14)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
 
 

! ! massive ferm loops
       PrimAmps(15)%ExtLine=(/1,2,5,3,4/)
       PrimAmps(15)%AmpType=2
       PrimAmps(15)%NumSisters=2
       PrimAmps(15)%FermLoopPart=Bot_
       PrimAmp2m_12534=15
       allocate( PrimAmps(15)%Sisters(1:PrimAmps(15)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
       PrimAmps(15)%Sisters(1) = 16
       PrimAmps(15)%Sisters(2) = 17
 
       PrimAmps(16)%ExtLine=(/1,2,3,5,4/)
       PrimAmps(16)%AmpType=2
       PrimAmps(16)%NumSisters=2
       PrimAmps(16)%FermLoopPart=Bot_
       PrimAmp2m_12354=16
       allocate( PrimAmps(16)%Sisters(1:PrimAmps(16)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
       PrimAmps(16)%Sisters(1) = 15
       PrimAmps(16)%Sisters(2) = 17
 
       PrimAmps(17)%ExtLine=(/1,2,3,4,5/)
       PrimAmps(17)%AmpType=2
       PrimAmps(17)%NumSisters=2
       PrimAmps(17)%FermLoopPart=Bot_
       PrimAmp2m_12345=17
       allocate( PrimAmps(17)%Sisters(1:PrimAmps(17)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
       PrimAmps(17)%Sisters(1) = 15
       PrimAmps(17)%Sisters(2) = 16
 
       PrimAmps(18)%ExtLine=(/1,2,5,4,3/)
       PrimAmps(18)%AmpType=2
       PrimAmps(18)%NumSisters=2
       PrimAmps(18)%FermLoopPart=Bot_
       PrimAmp2m_12543=18
       allocate( PrimAmps(18)%Sisters(1:PrimAmps(18)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
       PrimAmps(18)%Sisters(1) = 19
       PrimAmps(18)%Sisters(2) = 20
 
       PrimAmps(19)%ExtLine=(/1,2,4,5,3/)
       PrimAmps(19)%AmpType=2
       PrimAmps(19)%NumSisters=2
       PrimAmps(19)%FermLoopPart=Bot_
       PrimAmp2m_12453=19
       allocate( PrimAmps(19)%Sisters(1:PrimAmps(19)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
       PrimAmps(19)%Sisters(1) = 18
       PrimAmps(19)%Sisters(2) = 20
 
       PrimAmps(20)%ExtLine=(/1,2,4,3,5/)
       PrimAmps(20)%AmpType=2
       PrimAmps(20)%NumSisters=2
       PrimAmps(20)%FermLoopPart=Bot_
       PrimAmp2m_12435=20
       allocate( PrimAmps(20)%Sisters(1:PrimAmps(20)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
       PrimAmps(20)%Sisters(1) = 18
       PrimAmps(20)%Sisters(2) = 19
 
 
       PrimAmps(21)%ExtLine=(/1,5,2,3,4/)
       PrimAmps(21)%AmpType=2
       PrimAmps(21)%NumSisters=0
       PrimAmps(21)%FermLoopPart=Bot_
       PrimAmp2m_15234=21
       allocate( PrimAmps(21)%Sisters(1:PrimAmps(21)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
 
 
       PrimAmps(22)%ExtLine=(/1,5,2,4,3/)
       PrimAmps(22)%AmpType=2
       PrimAmps(22)%NumSisters=0
       PrimAmps(22)%FermLoopPart=Bot_
       PrimAmp2m_15243=22
       allocate( PrimAmps(22)%Sisters(1:PrimAmps(22)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
 
 
 !! RR added 1 March 2014 -- massive subleading color quark loops
 
       PrimAmps(23)%ExtLine=(/1,3,2,5,4/)
       PrimAmps(23)%AmpType=2
       PrimAmps(23)%NumSisters=1
       PrimAmps(23)%FermLoopPart=Bot_
       PrimAmp2m_13254=23
       allocate( PrimAmps(23)%Sisters(1:PrimAmps(23)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
       PrimAmps(23)%Sisters(1) =24
 
       PrimAmps(24)%ExtLine=(/1,3,2,4,5/)
       PrimAmps(24)%AmpType=2
       PrimAmps(24)%NumSisters=1
       PrimAmps(24)%FermLoopPart=Bot_
       PrimAmp2m_13245=24
       allocate( PrimAmps(24)%Sisters(1:PrimAmps(24)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
       PrimAmps(24)%Sisters(1) = 23
 
 
       PrimAmps(25)%ExtLine=(/1,4,2,5,3/)
       PrimAmps(25)%AmpType=2
       PrimAmps(25)%NumSisters=1
       PrimAmps(25)%FermLoopPart=Bot_
       PrimAmp2m_14253=25
       allocate( PrimAmps(25)%Sisters(1:PrimAmps(25)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
       PrimAmps(25)%Sisters(1) = 26
 
 
       PrimAmps(26)%ExtLine=(/1,4,2,3,5/)
       PrimAmps(26)%AmpType=2
       PrimAmps(26)%NumSisters=1
       PrimAmps(26)%FermLoopPart=Bot_
       PrimAmp2m_14235=26
       allocate( PrimAmps(26)%Sisters(1:PrimAmps(26)%NumSisters), stat=AllocStatus )
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
       PrimAmps(26)%Sisters(1) = 25


   ENDIF


ELSEIF( MASTERPROCESS.EQ.24 ) THEN! tb t qb q Higgs   ttbH

   IF( Correction.EQ.0  .OR. Correction.EQ.4 .OR.Correction.EQ.5 ) THEN
      BornAmps(1)%ExtLine = (/1,5,2,3,4/)
      PrimAmps(1)%ExtLine = (/1,5,2,3,4/)

   ELSEIF( Correction.EQ.1 ) THEN
       BornAmps(1)%ExtLine = (/1,5,2,3,4/)
       BornAmps(2)%ExtLine = (/1,5,2,3,4/)
       BornAmps(3)%ExtLine = (/1,5,4,3,2/)
       BornAmps(4)%ExtLine = (/1,4,3,5,2/)
       BornAmps(5)%ExtLine = (/1,5,2,3,4/)

       PrimAmps(1)%ExtLine = (/1,5,2,3,4/)
       PrimAmps(1)%AmpType = 1
       PrimAmps(1)%NumSisters = 0
       PrimAmp1_15234=1
       allocate( PrimAmps(1)%Sisters(1:PrimAmps(1)%NumSisters), stat=AllocStatus )      
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
 
       PrimAmps(2)%ExtLine = (/1,5,2,4,3/)
       PrimAmp1_15243 = 2
       PrimAmps(2)%AmpType = 1
       PrimAmps(2)%NumSisters = 0
       allocate( PrimAmps(2)%Sisters(1:PrimAmps(2)%NumSisters), stat=AllocStatus )      
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
 
       PrimAmps(3)%ExtLine = (/1,5,4,3,2/)
       PrimAmp3_15432 = 3
       PrimAmps(3)%AmpType = 3
       PrimAmps(3)%NumSisters = 0
       allocate( PrimAmps(3)%Sisters(1:PrimAmps(3)%NumSisters), stat=AllocStatus )      
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
 
       PrimAmps(4)%ExtLine = (/1,4,3,5,2/)! MARKUS: new primamp with Z on bottom
       PrimAmp3_14352 = 4
       PrimAmps(4)%AmpType = 3
       PrimAmps(4)%NumSisters = 0
       allocate( PrimAmps(4)%Sisters(1:PrimAmps(4)%NumSisters), stat=AllocStatus )      
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
 
       PrimAmps(5)%ExtLine = (/1,5,2,3,4/)
       PrimAmp4_15234 = 5
       PrimAmps(5)%AmpType = 4
       PrimAmps(5)%NumSisters = 0
       allocate( PrimAmps(5)%Sisters(1:PrimAmps(5)%NumSisters), stat=AllocStatus )      
       if( AllocStatus .ne. 0 ) call Error("Memory allocation for Sisters")
 
 
! ! ferm loops begin here    

       PrimAmps(6)%ExtLine=(/1,2,5,3,4/)
       PrimAmps(6)%AmpType=2
       PrimAmps(6)%NumSisters=0
       PrimAmps(6)%FermLoopPart=Bot_
       PrimAmp2m_12534=6
       allocate( PrimAmps(6)%Sisters(1:PrimAmps(6)%NumSisters), stat=AllocStatus )
 
       PrimAmps(7)%ExtLine=(/1,2,3,4,5/)
       PrimAmps(7)%AmpType=2
       PrimAmps(7)%NumSisters=0
       PrimAmps(7)%FermLoopPart=Bot_
       PrimAmp2m_12345=7
       allocate( PrimAmps(7)%Sisters(1:PrimAmps(7)%NumSisters), stat=AllocStatus )  
 
       PrimAmps(8)%ExtLine=(/1,5,2,3,4/)
       PrimAmps(8)%AmpType=2
       PrimAmps(8)%NumSisters=0
       PrimAmps(8)%FermLoopPart=Chm_
       PrimAmp2_15234=8
       allocate( PrimAmps(8)%Sisters(1:PrimAmps(8)%NumSisters), stat=AllocStatus )
 
       PrimAmps(9)%ExtLine=(/1,5,2,3,4/)
       PrimAmps(9)%AmpType=2
       PrimAmps(9)%NumSisters=0
       PrimAmps(9)%FermLoopPart=Bot_
       PrimAmp2m_15234=9
       allocate( PrimAmps(9)%Sisters(1:PrimAmps(9)%NumSisters), stat=AllocStatus )
 
   ENDIF



ELSEIF( MasterProcess.EQ.25 ) THEN

   IF( Correction.EQ.2 ) THEN
!       PrimAmps(1)%ExtLine = (/1,6,2,3,4,5/)
!       BornAmps(1)%ExtLine = (/1,6,2,3,4,5/)
! 
!       PrimAmps(2)%ExtLine = (/1,6,2,3,5,4/)
!       BornAmps(2)%ExtLine = (/1,6,2,3,5,4/)
! 
!       PrimAmps(3)%ExtLine = (/1,6,2,4,3,5/)
!       BornAmps(3)%ExtLine = (/1,6,2,4,3,5/)
! 
!       PrimAmps(4)%ExtLine = (/1,6,2,4,5,3/)
!       BornAmps(4)%ExtLine = (/1,6,2,4,5,3/)
! 
!       PrimAmps(5)%ExtLine = (/1,6,2,5,3,4/)
!       BornAmps(5)%ExtLine = (/1,6,2,5,3,4/)
! 
!       PrimAmps(6)%ExtLine = (/1,6,2,5,4,3/)
!       BornAmps(6)%ExtLine = (/1,6,2,5,4,3/)

      
      
! use new feature in SetPolarizations: need to start with gluon      
      PrimAmps(1)%ExtLine = (/3,4,5,1,6,2/)
      BornAmps(1)%ExtLine = (/3,4,5,1,6,2/)

      PrimAmps(2)%ExtLine = (/3,5,4,1,6,2/)
      BornAmps(2)%ExtLine = (/3,5,4,1,6,2/)

      PrimAmps(3)%ExtLine = (/3,5,1,6,2,4/)
      BornAmps(3)%ExtLine = (/3,5,1,6,2,4/)

      PrimAmps(4)%ExtLine = (/3,1,6,2,4,5/)
      BornAmps(4)%ExtLine = (/3,1,6,2,4,5/)

      PrimAmps(5)%ExtLine = (/3,4,1,6,2,5/)
      BornAmps(5)%ExtLine = (/3,4,1,6,2,5/)

      PrimAmps(6)%ExtLine = (/3,1,6,2,5,4/)
      BornAmps(6)%ExtLine = (/3,1,6,2,5,4/)
      
      
   ENDIF



ELSEIF( MasterProcess.EQ.26 ) THEN

   IF( Correction.EQ.2 ) THEN

!       PrimAmps( 1)%ExtLine = (/1,6,2,3,4,5/)
!       BornAmps( 1)%ExtLine = (/1,6,2,3,4,5/)
!       PrimAmp1_162345 = 1
! 
!       PrimAmps( 2)%ExtLine = (/1,6,2,5,3,4/)
!       BornAmps( 2)%ExtLine = (/1,6,2,5,3,4/)
!       PrimAmp1_162534 = 2
! 
!       PrimAmps( 3)%ExtLine = (/1,6,5,2,3,4/)
!       BornAmps( 3)%ExtLine = (/1,6,5,2,3,4/)
!       PrimAmp1_165234 = 3
! 
!       PrimAmps( 4)%ExtLine = (/1,6,2,3,5,4/)
!       BornAmps( 4)%ExtLine = (/1,6,2,3,5,4/)
!       PrimAmp1_162354 = 4
      
! use new feature in SetPolarizations: need to start with gluon      
!       PrimAmps( 1)%ExtLine = (/5,1,6,2,3,4/)!  doesn't work because some currents are missing
!       BornAmps( 1)%ExtLine = (/5,1,6,2,3,4/)
!       PrimAmp1_162345 = 1
! 
!       PrimAmps( 2)%ExtLine = (/5,3,4,1,6,2/)
!       BornAmps( 2)%ExtLine = (/5,3,4,1,6,2/)
!       PrimAmp1_162534 = 2
! 
!       PrimAmps( 3)%ExtLine = (/5,2,3,4,1,6/)
!       BornAmps( 3)%ExtLine = (/5,2,3,4,1,6/)
!       PrimAmp1_165234 = 3
! 
!       PrimAmps( 4)%ExtLine = (/5,4,1,6,2,3/)
!       BornAmps( 4)%ExtLine = (/5,4,1,6,2,3/)
!       PrimAmp1_162354 = 4
      
      

! use new feature in SetPolarizations: need to start with massless quark
      PrimAmps( 1)%ExtLine = (/3,4,5,1,6,2/)
      BornAmps( 1)%ExtLine = (/3,4,5,1,6,2/)
      PrimAmp1_162345 = 1

      PrimAmps( 3)%ExtLine = (/3,4,1,6,2,5/)! note that prim.amp 2<-->3 wrt. to above
      BornAmps( 3)%ExtLine = (/3,4,1,6,2,5/)
      PrimAmp1_162534 = 3

      PrimAmps( 2)%ExtLine = (/3,4,1,6,5,2/)
      BornAmps( 2)%ExtLine = (/3,4,1,6,5,2/)
      PrimAmp1_165234 = 2

      PrimAmps( 4)%ExtLine = (/3,5,4,1,6,2/)
      BornAmps( 4)%ExtLine = (/3,5,4,1,6,2/)
      PrimAmp1_162354 = 4
      
   ENDIF

   




ELSEIF( MASTERPROCESS.EQ.31 ) THEN!  this is a copy of Masterprocess 1 which is used for T' production
   IF ( Correction.EQ.1 ) THEN
   BornAmps(1)%ExtLine = (/1,2,3,4/)
   BornAmps(2)%ExtLine = (/1,2,4,3/)

   PrimAmps(1)%ExtLine = (/1,2,3,4/)
   PrimAmp1_1234 = 2
   PrimAmps(1)%AmpType = 1

   PrimAmps(2)%ExtLine = (/1,2,4,3/)
   PrimAmp1_1243 = 1
   PrimAmps(2)%AmpType = 1

   PrimAmps(3)%ExtLine = (/1,3,2,4/)
   PrimAmp1_1324 = 3
   PrimAmps(3)%AmpType = 1

   PrimAmps(4)%ExtLine = (/1,4,2,3/)
   PrimAmp1_1423 = 4
   PrimAmps(4)%AmpType = 1

   PrimAmps(5)%ExtLine = (/1,3,4,2/)
   PrimAmp1_1342 = 6
   PrimAmps(5)%AmpType = 1

   PrimAmps(6)%ExtLine = (/1,4,3,2/)
   PrimAmp1_1432 = 5
   PrimAmps(6)%AmpType = 1

   PrimAmps(7)%ExtLine = (/1,2,3,4/)
   PrimAmp2_1234 = 1
   PrimAmps(7)%AmpType = 2
   PrimAmps(7)%FermLoopPart = Chm_

   PrimAmps(8)%ExtLine = (/1,2,4,3/)
   PrimAmp2_1243 = 2
   PrimAmps(8)%AmpType = 2
   PrimAmps(8)%FermLoopPart = Chm_

   PrimAmps(9)%ExtLine = (/1,2,3,4/)
   PrimAmp2m_1234 = 1
   PrimAmps(9)%AmpType = 2
   PrimAmps(9)%FermLoopPart = Bot_

   PrimAmps(10)%ExtLine = (/1,2,4,3/)
   PrimAmp2m_1243 = 2
   PrimAmps(10)%AmpType = 2
   PrimAmps(10)%FermLoopPart = Bot_

   PrimAmps(11)%ExtLine = (/1,2,3,4/)
!    PrimAmp2m_1234 = 1
   PrimAmps(11)%AmpType = 2
   PrimAmps(11)%FermLoopPart = HTop_  !   the label HTop is only used for closed T' loops

   PrimAmps(12)%ExtLine = (/1,2,4,3/)
!    PrimAmp2m_1243 = 2
   PrimAmps(12)%AmpType = 2
   PrimAmps(12)%FermLoopPart = HTop_


   ELSEIF( Correction.EQ.0 .OR. Correction.GE.4 ) THEN
   BornAmps(1)%ExtLine = (/1,2,3,4/)
   BornAmps(2)%ExtLine = (/1,2,4,3/)

   PrimAmps(1)%ExtLine = (/1,2,3,4/)
   PrimAmps(2)%ExtLine = (/1,2,4,3/)
   ENDIF


ELSEIF( MasterProcess.EQ.32) THEN!  this is a copy of Masterprocess 2 which is used for T' production
   IF( Correction.EQ.1 ) THEN
   BornAmps(1)%ExtLine = (/1,2,3,4/)
   BornAmps(2)%ExtLine = (/1,2,3,4/)
   BornAmps(3)%ExtLine = (/1,4,3,2/)
   BornAmps(4)%ExtLine = (/1,2,3,4/)
   BornAmps(5)%ExtLine = (/1,2,3,4/)
   BornAmps(6)%ExtLine = (/1,2,3,4/)

   PrimAmps(1)%ExtLine = (/1,2,3,4/)
   PrimAmp1_1234 = 1
   PrimAmps(1)%AmpType = 1

   PrimAmps(2)%ExtLine = (/1,2,4,3/)
   PrimAmp1_1243 = 2
   PrimAmps(2)%AmpType = 1

!    PrimAmps(3)%ExtLine = (/1,3,4,2/)
   PrimAmps(3)%ExtLine = (/1,4,3,2/)
   PrimAmp3_1432 = 3
   PrimAmps(3)%AmpType = 3

!    PrimAmps(4)%ExtLine = (/1,2,4,3/)
   PrimAmps(4)%ExtLine = (/1,2,3,4/)
   PrimAmp4_1234 = 4
   PrimAmps(4)%AmpType = 4

   PrimAmps(5)%ExtLine = (/1,2,3,4/)
   PrimAmp2_1234 = 5
   PrimAmps(5)%AmpType = 2
   PrimAmps(5)%FermLoopPart = Chm_

   PrimAmps(6)%ExtLine = (/1,2,3,4/)
   PrimAmp2m_1234 = 6
   PrimAmps(6)%AmpType = 2
   PrimAmps(6)%FermLoopPart = Bot_

   PrimAmps(7)%ExtLine = (/1,2,3,4/)
!    PrimAmp2m_1234 = 7
   PrimAmps(7)%AmpType = 2
   PrimAmps(7)%FermLoopPart = HTop_!   the label HTop is only used for closed T' loops

   ELSEIF ( Correction.EQ.0 .OR. Correction.GE.4 ) THEN
    BornAmps(1)%ExtLine = (/1,2,3,4/)
    PrimAmps(1)%ExtLine = (/1,2,3,4/)
   ENDIF




ELSEIF( MasterProcess.EQ.41) THEN
!   do nothing 


ELSEIF( MasterProcess.EQ.42) THEN
!   do nothing 


ELSEIF( MasterProcess.EQ.43) THEN
!   do nothing 


ELSEIF( MasterProcess.EQ.44) THEN
!   do nothing 


ELSEIF( MasterProcess.EQ.45) THEN
!   do nothing 


ELSEIF( MasterProcess.EQ.46) THEN
!   do nothing 






ELSEIF( MasterProcess.EQ.62) THEN
!   IF( Correction.EQ.0 .OR. Correction.EQ.1 .OR. Correction.EQ.3 .OR. Correction.GE.4 ) THEN
!   BornAmps(1)%ExtLine = (/1,2,3,4/)
!   PrimAmps(1)%ExtLine = (/1,2,3,4/)
!   ENDIF

ELSEIF( MasterProcess.EQ.63) THEN
!   IF( Correction.EQ.2 ) THEN
!      BornAmps(1)%ExtLine = (/1,2,3,5,4/) ! Emission from the light line
!      PrimAmps(1)%ExtLine = (/1,2,3,5,4/) ! Emission from the light line
!      BornAmps(2)%ExtLine = (/1,5,2,3,4/) ! Emission from the heavy
!      PrimAmps(2)%ExtLine = (/1,5,2,3,4/) ! Emission from the heavy
!   ENDIF



ELSEIF( MasterProcess.EQ.73 ) THEN ! t+H

   IF( Correction.EQ.0 .OR. Correction.EQ.4 .OR.Correction.EQ.5 ) THEN
      BornAmps(1)%ExtLine = (/1,5,2,3,4/)
      PrimAmps(1)%ExtLine = (/1,5,2,3,4/)
   ENDIF

ELSEIF( MasterProcess.EQ.74 ) THEN ! tb+H                                                                                                                                 
   IF( Correction.EQ.0 .OR. Correction.EQ.4 .OR.Correction.EQ.5 ) THEN
      BornAmps(1)%ExtLine = (/1,5,2,3,4/)
      PrimAmps(1)%ExtLine = (/1,5,2,3,4/)
   ENDIF


ELSE
    call Error("MasterProcess not implemented in InitAmps")

ENDIF





!  loop over all born amplitudes
!    do NPrimAmp=1,NumBornAmps
   do NPrimAmp=1,NumPrimAmps
!!!!!! overwriting bornamps initializations  !!!!
            BornAmps(NPrimAmp)%ExtLine = PrimAmps(NPrimAmp)%ExtLine
!!!!!!
            TheBornAmp => BornAmps(NPrimAmp)
            TheTree => TheBornAmp%TreeProc
            TheTree%NumPart = NumExtParticles
            allocate( TheTree%PartType(1:NumExtParticles), stat=AllocStatus )
            if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartType for Born")
            allocate( TheTree%PartRef(1:NumExtParticles), stat=AllocStatus )
            if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartRef for Born")
            TheTree%PartRef(1:NumExtParticles) = BornAmps(NPrimAmp)%ExtLine(1:NumExtParticles)
!           set number of quarks and gluons and scalars and vector bosons
            TheTree%NumQua = 0
            TheTree%NumSca = 0
            TheTree%NumW = 0
            TheTree%NumV = 0
            counterQ = 0
            counterG = 0
            do NPart=1,TheTree%NumPart
                  TheTree%PartType(NPart) = ExtParticle( TheBornAmp%ExtLine(NPart) )%PartType
                  if( IsAQuark(TheTree%PartType(NPart)) ) then
                     TheTree%NumQua = TheTree%NumQua + 1
                     counterQ = counterQ + 1
                     QuarkPos(counterQ) = counterQ + counterG
!                      LastQuark = NPart! only required for BosonVertex below  THIS WAS A BUG
                     LastQuark = counterQ! only required for BosonVertex below
                  elseif( IsAScalar(TheTree%PartType(NPart)) ) then
                     TheTree%NumSca = TheTree%NumSca + 1
                     counterQ = counterQ + 1!     treat the scalar like a quark here because this is only to determine NumGlu 
                     QuarkPos(counterQ) = counterQ + counterG
                  elseif( TheTree%PartType(NPart).eq.Glu_ ) then
                     counterG = counterG + 1
                  elseif( IsABoson(TheTree%PartType(NPart)) ) then! careful: bosons should only be placed *between* same flavor quark lines
                     if( NPart.eq.1 ) call Error("Vector boson should not be the first particle.")
                     if( abs(TheTree%PartType(NPart)).eq.abs(Wp_) ) TheTree%NumW = TheTree%NumW + 1
                     if( abs(TheTree%PartType(NPart)).eq.abs(Z0_) ) TheTree%NumV = TheTree%NumV + 1
                     if( abs(TheTree%PartType(NPart)).eq.abs(Pho_)) TheTree%NumV = TheTree%NumV + 1
                     if( abs(TheTree%PartType(NPart)).eq.abs(Hig_)) TheTree%NumV = TheTree%NumV + 1
!                     TheTree%BosonVertex = TheTree%PartType(LastQuark)! this variable specifies to which quark flavor the vector boson couples
                     TheTree%BosonVertex = LastQuark! this variable specifies the position of the boson wrt. to the quark lines
                  endif
            enddo
            if( IsAQuark(TheTree%PartType(1)) .or. IsAScalar(TheTree%PartType(1)) ) then
               allocate( TheTree%NumGlu(0:TheTree%NumQua+TheTree%NumSca), stat=AllocStatus )
               TheTree%NumGlu(0:TheTree%NumQua+TheTree%NumSca) = 0
            elseif( TheTree%PartType(1).eq.Glu_ ) then
               allocate( TheTree%NumGlu(0:TheTree%NumQua+TheTree%NumSca+1), stat=AllocStatus )
               TheTree%NumGlu(0:TheTree%NumQua+TheTree%NumSca+1) = 0
            else
               call Error("TheTree%NumGlu")
            endif
            if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%NumGlu")
            do NPart=1,TheTree%NumPart
                  if( TheTree%PartType(NPart) .eq. Glu_ ) then
                     TheTree%NumGlu(0) = TheTree%NumGlu(0) + 1!  total numbers of gluons
                  endif
            enddo
!           set number of gluons between quark or scalar lines
            if( IsAQuark(TheTree%PartType(1)) .or. IsAScalar(TheTree%PartType(1)) ) then
              if( TheTree%NumQua+TheTree%NumSca .eq. 2 ) then
                    TheTree%NumGlu(1) = QuarkPos(2) - QuarkPos(1) - 1
                    TheTree%NumGlu(2) = TheTree%NumGlu(0)+TheTree%NumQua+TheTree%NumSca - QuarkPos(2)
                    if( TheTree%NumGlu(0)-TheTree%NumGlu(1)-TheTree%NumGlu(2).ne.0 ) call Error("Wrong number of gluons in TheTree%NumGlu")
              endif
              if( TheTree%NumQua+TheTree%NumSca .eq. 4 ) then
                    TheTree%NumGlu(1) = QuarkPos(2) - QuarkPos(1) - 1
                    TheTree%NumGlu(2) = QuarkPos(3) - QuarkPos(2) - 1
                    TheTree%NumGlu(3) = QuarkPos(4) - QuarkPos(3) - 1
                    TheTree%NumGlu(4) = TheTree%NumGlu(0)+TheTree%NumQua+TheTree%NumSca - QuarkPos(4)
                    if( TheTree%NumGlu(0)-TheTree%NumGlu(1)-TheTree%NumGlu(2)-TheTree%NumGlu(3)-TheTree%NumGlu(4).ne.0 ) call Error("Wrong number of gluons in TheTree%NumGlu")
              endif
              if( TheTree%NumQua+TheTree%NumSca .eq. 6 ) then
                    TheTree%NumGlu(1) = QuarkPos(2) - QuarkPos(1) - 1
                    TheTree%NumGlu(2) = QuarkPos(3) - QuarkPos(2) - 1
                    TheTree%NumGlu(3) = QuarkPos(4) - QuarkPos(3) - 1
                    TheTree%NumGlu(4) = QuarkPos(5) - QuarkPos(4) - 1
                    TheTree%NumGlu(5) = QuarkPos(6) - QuarkPos(5) - 1
                    TheTree%NumGlu(6) = TheTree%NumGlu(0)+TheTree%NumQua+TheTree%NumSca - QuarkPos(6)
                    if( TheTree%NumGlu(0)-TheTree%NumGlu(1)-TheTree%NumGlu(2)-TheTree%NumGlu(3)-TheTree%NumGlu(4)-TheTree%NumGlu(5)-TheTree%NumGlu(6).ne.0 ) call Error("Wrong number of gluons in TheTree%NumGlu")
              endif

            elseif( TheTree%PartType(1).eq.Glu_ ) then
              if( TheTree%NumQua+TheTree%NumSca .eq. 2 ) then
                    TheTree%NumGlu(1) = QuarkPos(1) - 2
                    TheTree%NumGlu(2) = QuarkPos(2) - QuarkPos(1) - 1
                    TheTree%NumGlu(3) = TheTree%NumGlu(0)+TheTree%NumQua+TheTree%NumSca - QuarkPos(2)
                    if( TheTree%NumGlu(0)-TheTree%NumGlu(1)-TheTree%NumGlu(2)-TheTree%NumGlu(3)-1.ne.0 ) call Error("Wrong number of gluons in TheTree%NumGlu",1)
              endif
              if( TheTree%NumQua+TheTree%NumSca .eq. 4 ) then
                    TheTree%NumGlu(1) = QuarkPos(1) - 2
                    TheTree%NumGlu(2) = QuarkPos(2) - QuarkPos(1) - 1
                    TheTree%NumGlu(3) = QuarkPos(3) - QuarkPos(2) - 1
                    TheTree%NumGlu(4) = QuarkPos(4) - QuarkPos(3) - 1
                    TheTree%NumGlu(5) = TheTree%NumGlu(0)+TheTree%NumQua+TheTree%NumSca - QuarkPos(4)
                    if( TheTree%NumGlu(0)-TheTree%NumGlu(1)-TheTree%NumGlu(2)-TheTree%NumGlu(3)-TheTree%NumGlu(4)-TheTree%NumGlu(5).ne.0 ) call Error("Wrong number of gluons in TheTree%NumGlu",2)
              endif
              if( TheTree%NumQua+TheTree%NumSca .eq. 6 ) then
                    TheTree%NumGlu(1) = QuarkPos(1) - 2
                    TheTree%NumGlu(2) = QuarkPos(2) - QuarkPos(1) - 1
                    TheTree%NumGlu(3) = QuarkPos(3) - QuarkPos(2) - 1
                    TheTree%NumGlu(4) = QuarkPos(4) - QuarkPos(3) - 1
                    TheTree%NumGlu(5) = QuarkPos(5) - QuarkPos(4) - 1
                    TheTree%NumGlu(6) = QuarkPos(6) - QuarkPos(5) - 1
                    TheTree%NumGlu(7) = TheTree%NumGlu(0)+TheTree%NumQua+TheTree%NumSca - QuarkPos(6)
                    if( TheTree%NumGlu(0)-TheTree%NumGlu(1)-TheTree%NumGlu(2)-TheTree%NumGlu(3)-TheTree%NumGlu(4)-TheTree%NumGlu(5)-TheTree%NumGlu(6)-TheTree%NumGlu(7).ne.0 ) call Error("Wrong number of gluons in TheTree%NumGlu",3)
              endif
            else
                call Error("Invalid first particle",TheTree%PartType(1))
            endif


!          allocate memory for pointer to quarks
           allocate( TheTree%Quarks(1:TheTree%NumQua), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%Quarks")

!          allocate memory for pointer to scalars
           allocate( TheTree%Scalars(1:TheTree%NumSca), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%Scalars")

!          allocate memory for pointer to gluons
           allocate( TheTree%Gluons(1:TheTree%NumGlu(0)), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%Gluons")

           counterQ = 0
           counterG = 0
           counterS = 0
           counterV = 0

           do NPart=1,TheTree%NumPart
               if( IsAQuark(TheTree%PartType(NPart)) ) then
                     counterQ = counterQ + 1
                     TheTree%Quarks(counterQ)%PartType => ExtParticle( TheBornAmp%ExtLine(NPart) )%PartType
                     TheTree%Quarks(counterQ)%ExtRef => ExtParticle( TheBornAmp%ExtLine(NPart) )%ExtRef
                     TheTree%Quarks(counterQ)%Mass => ExtParticle( TheBornAmp%ExtLine(NPart) )%Mass
                     TheTree%Quarks(counterQ)%Mass2 => ExtParticle( TheBornAmp%ExtLine(NPart) )%Mass2
                     TheTree%Quarks(counterQ)%Helicity => ExtParticle( TheBornAmp%ExtLine(NPart) )%Helicity
                     TheTree%Quarks(counterQ)%Mom => ExtParticle( TheBornAmp%ExtLine(NPart) )%Mom
                     TheTree%Quarks(counterQ)%Pol => ExtParticle( TheBornAmp%ExtLine(NPart) )%Pol
               endif
               if( TheTree%PartType(NPart) .eq. Glu_ ) then
                     counterG = counterG + 1
                     TheTree%Gluons(counterG)%PartType => ExtParticle( TheBornAmp%ExtLine(NPart) )%PartType
                     TheTree%Gluons(counterG)%ExtRef => ExtParticle( TheBornAmp%ExtLine(NPart) )%ExtRef
                     TheTree%Gluons(counterG)%Mass => ExtParticle( TheBornAmp%ExtLine(NPart) )%Mass
                     TheTree%Gluons(counterG)%Mass2 => ExtParticle( TheBornAmp%ExtLine(NPart) )%Mass2
                     TheTree%Gluons(counterG)%Helicity => ExtParticle( TheBornAmp%ExtLine(NPart) )%Helicity
                     TheTree%Gluons(counterG)%Mom => ExtParticle( TheBornAmp%ExtLine(NPart) )%Mom
                     TheTree%Gluons(counterG)%Pol => ExtParticle( TheBornAmp%ExtLine(NPart) )%Pol
               endif
               if( IsAScalar(TheTree%PartType(NPart)) ) then
                     counterS = counterS + 1
                     TheTree%Scalars(counterS)%PartType => ExtParticle( TheBornAmp%ExtLine(NPart) )%PartType
                     TheTree%Scalars(counterS)%ExtRef => ExtParticle( TheBornAmp%ExtLine(NPart) )%ExtRef
                     TheTree%Scalars(counterS)%Mass => ExtParticle( TheBornAmp%ExtLine(NPart) )%Mass
                     TheTree%Scalars(counterS)%Mass2 => ExtParticle( TheBornAmp%ExtLine(NPart) )%Mass2
                     TheTree%Scalars(counterS)%Helicity => ExtParticle( TheBornAmp%ExtLine(NPart) )%Helicity
                     TheTree%Scalars(counterS)%Mom => ExtParticle( TheBornAmp%ExtLine(NPart) )%Mom
                     TheTree%Scalars(counterS)%Pol => ExtParticle( TheBornAmp%ExtLine(NPart) )%Pol
               endif

               if( IsABoson(TheTree%PartType(NPart)) ) then
                     counterV = counterV + 1
                     if( counterV.ge.2 ) call Error("only one vector boson allowed",counterV)
                     TheTree%Boson%PartType => ExtParticle( TheBornAmp%ExtLine(NPart) )%PartType
                     TheTree%Boson%ExtRef => ExtParticle( TheBornAmp%ExtLine(NPart) )%ExtRef
                     TheTree%Boson%Mass => ExtParticle( TheBornAmp%ExtLine(NPart) )%Mass
                     TheTree%Boson%Mass2 => ExtParticle( TheBornAmp%ExtLine(NPart) )%Mass2
                     TheTree%Boson%Helicity => ExtParticle( TheBornAmp%ExtLine(NPart) )%Helicity
                     TheTree%Boson%Mom => ExtParticle( TheBornAmp%ExtLine(NPart) )%Mom
                     TheTree%Boson%Pol => ExtParticle( TheBornAmp%ExtLine(NPart) )%Pol
               endif

           enddo
   enddo



IF( Correction.EQ.1 ) THEN
!  loop over all primitive amplitudes
   do NPrimAmp=1,NumPrimAmps

         ThePrimAmp => PrimAmps(NPrimAmp)
         ColorLessParticles = .false.
         ThePrimAmp%IntPart(1:NumExtParticles)%PartType = 99

         ExtPartType = ExtParticle( ThePrimAmp%ExtLine(1) )%PartType
!  set internal lines: associate each int.line with the ext.line at the next vertex
!  negativ  IntPart()%PartType <--> fermion flow along ascending  propagators
!  positive IntPart()%PartType <--> fermion flow along descending propagators


!  determine number of quark lines
!  scalar lines are treated like fermion lines here. in particular, FermLine1=Scalar line , FermLine2=Quark line, assuming the corresp. ordering of the prim.ampl.
         ThePrimAmp%FermLine1In = 0
         ThePrimAmp%FermLine1Out= 0
         ThePrimAmp%FermLine2In = 0
         ThePrimAmp%FermLine2Out= 0
         ThePrimAmp%ScaLine1In = 0
         ThePrimAmp%ScaLine1Out= 0
!          print *, "Primamp type",ThePrimAmp%ampType
!          print *, "Primamp",ThePrimAmp%ExtLine
         do Vertex=1,NumExtParticles;  !      print *, "Vertex",Vertex
            Propa       = Vertex + 1
            PropaMinus1 = Propa - 1
            ExtPartType = ExtParticle( ThePrimAmp%ExtLine(Vertex) )%PartType
            if( Vertex .eq. NumExtParticles ) then
               Propa       = 1
               PropaMinus1 = NumExtParticles
            endif
            if ( Vertex.eq.1 ) then
               ThePrimAmp%IntPart(Propa)%PartType = ExtPartType
               if( IsAQuark(ExtPartType) ) then
                  ThePrimAmp%FermionLines = 1
                  ThePrimAmp%FermLine1In  = 1
               elseif( IsAScalar(ExtPartType) ) then
                  ThePrimAmp%FermionLines = 1
                  ThePrimAmp%FermLine1In  = 1
               else
                  ThePrimAmp%FermionLines = 0
               endif

            elseif( IsAQuark(ExtPartType) ) then
               if( ThePrimAmp%AmpType.eq.1 ) then
                   if( ThePrimAmp%FermLine1Out.eq.0 ) then
                      ThePrimAmp%FermLine1Out = Vertex
                      ThePrimAmp%IntPart(Propa)%PartType = Glu_
                   elseif( ThePrimAmp%FermLine2In.eq.0 ) then
                      ThePrimAmp%FermionLines = 2
                      ThePrimAmp%FermLine2In = Vertex
                      ThePrimAmp%IntPart(Propa)%PartType = ExtPartType
                   elseif( ThePrimAmp%FermLine2Out.eq.0 ) then
                      ThePrimAmp%FermLine2Out = Vertex
                      ThePrimAmp%IntPart(Propa)%PartType = Glu_
                   endif

               elseif( ThePrimamp%AmpType.eq.2 ) then
                   if( ThePrimAmp%FermLine1Out.eq.0 ) then
                            ThePrimAmp%FermLine1Out = Vertex
                            ThePrimAmp%IntPart(1)%PartType = -abs(ThePrimAmp%FermLoopPart)
                            ThePrimAmp%IntPart(Propa)%PartType = -abs(ThePrimAmp%FermLoopPart)
                            do k=ThePrimAmp%FermLine1In+1,ThePrimAmp%FermLine1Out
                                ThePrimAmp%IntPart(k)%PartType = 0
                            enddo
                   elseif( ThePrimAmp%FermLine2In.eq.0 ) then
                            ThePrimAmp%FermionLines = 2
                            ThePrimAmp%FermLine2In = Vertex
                   elseif( ThePrimAmp%FermLine2Out.eq.0 ) then
                            ThePrimAmp%FermLine2Out = Vertex
                            do k=ThePrimAmp%FermLine2In+1,ThePrimAmp%FermLine2Out
                                ThePrimAmp%IntPart(k)%PartType = 0
                            enddo
                            do k=ThePrimAmp%FermLine2Out+1,NumExtParticles
                                ThePrimAmp%IntPart(k)%PartType = -abs(ThePrimAmp%FermLoopPart)
                            enddo

!                    elseif( ThePrimAmp%FermLine1In.eq.0 .and. ThePrimAmp%ScaLine1Out.ne.0 ) then! this is for the case when a scalar line is on the other side of the fermion loop
!                             ThePrimAmp%FermionLines = 1
!                             ThePrimAmp%FermLine1In = Vertex
!                    elseif( ThePrimAmp%FermLine1Out.eq.0  .and. ThePrimAmp%ScaLine1Out.ne.0 ) then! this is for the case when a scalar line is on the other side of the fermion loop
!                             ThePrimAmp%FermLine1Out = Vertex
!                             do k=ThePrimAmp%FermLine1In+1,ThePrimAmp%FermLine1Out
!                                 ThePrimAmp%IntPart(k)%PartType = 0
!                             enddo
!                             do k=ThePrimAmp%FermLine1Out+1,NumExtParticles
!                                 ThePrimAmp%IntPart(k)%PartType = -abs(ThePrimAmp%FermLoopPart)
!                             enddo
                   endif

               elseif( ThePrimamp%AmpType.eq.3 ) then
                       if( ThePrimAmp%FermLine2In.eq.0 ) then
                          ThePrimAmp%FermionLines = 2
                          ThePrimAmp%FermLine2In = Vertex
                       elseif( ThePrimAmp%FermLine2Out.eq.0 ) then
                          ThePrimAmp%FermLine2Out = Vertex
                          ThePrimAmp%IntPart(Propa)%PartType = ThePrimAmp%IntPart(ThePrimAmp%FermLine2In)%PartType
                          do k=ThePrimAmp%FermLine2In+1,ThePrimAmp%FermLine2Out
                              ThePrimAmp%IntPart(k)%PartType = 0
                          enddo
                       elseif( ThePrimAmp%FermLine1Out.eq.0 ) then
                           ThePrimAmp%FermLine1Out = Vertex
                           ThePrimAmp%IntPart(Propa)%PartType = Glu_
                       endif

               elseif( ThePrimamp%AmpType.eq.4 ) then
                       if( ThePrimAmp%FermLine1Out.eq.0 ) then
                           ThePrimAmp%FermLine1Out = Vertex
                           do k=ThePrimAmp%FermLine1In+1,ThePrimAmp%FermLine1Out
                              ThePrimAmp%IntPart(k)%PartType = 0
                           enddo
                       elseif( ThePrimAmp%FermLine2In.eq.0 ) then
                           ThePrimAmp%FermionLines = 2
                           ThePrimAmp%FermLine2In = Vertex
                            ThePrimAmp%IntPart(Propa)%PartType = Glu_
                            do k=ThePrimAmp%FermLine1Out+1,ThePrimAmp%FermLine2In
                                ThePrimAmp%IntPart(k)%PartType = -ExtPartType
                            enddo
                            ThePrimAmp%IntPart(1)%PartType = -ExtPartType
                       elseif( ThePrimAmp%FermLine2Out.eq.0 ) then
                            ThePrimAmp%FermLine2Out = Vertex
                            do k=ThePrimAmp%FermLine2Out+1,NumExtParticles
                                ThePrimAmp%IntPart(k)%PartType = ExtPartType
                            enddo
                       endif
!                        print *, "remember: check again this code, int/ext particles and trees"
               endif

            elseif( (ExtPartType .eq. Glu_) ) then
               ThePrimAmp%IntPart(Propa)%PartType = ThePrimAmp%IntPart(PropaMinus1)%PartType

            elseif( IsAScalar(ExtPartType) ) then
!             print *, "IsAScalar(ExtPartType)"
               if( ThePrimAmp%AmpType.eq.1 ) then
                   if( ThePrimAmp%FermLine1Out.eq.0 ) then
                      ThePrimAmp%FermLine1Out = Vertex
                      ThePrimAmp%IntPart(Propa)%PartType = Glu_
!                    elseif( ThePrimAmp%FermLine1In.eq.0 ) then
!                       ThePrimAmp%FermionLines = 1
!                       ThePrimAmp%FermLine1In = Vertex
!                       ThePrimAmp%IntPart(Propa)%PartType = ExtPartType
!                    elseif( ThePrimAmp%FermLine1Out.eq.0 ) then
!                       ThePrimAmp%FermLine1Out = Vertex
!                       ThePrimAmp%IntPart(Propa)%PartType = Glu_
                   else
                        call Error("something's missing here")
                   endif

               elseif( ThePrimamp%AmpType.eq.2 ) then
                   if( ThePrimAmp%FermLine1Out.eq.0 ) then
                            ThePrimAmp%FermLine1Out = Vertex
                            ThePrimAmp%IntPart(1)%PartType = -abs(ThePrimAmp%FermLoopPart)
                            ThePrimAmp%IntPart(Propa)%PartType = -abs(ThePrimAmp%FermLoopPart)
                            do k=ThePrimAmp%FermLine1In+1,ThePrimAmp%FermLine1Out
                                ThePrimAmp%IntPart(k)%PartType = 0
                            enddo
!                    elseif( ThePrimAmp%FermLine2In.eq.0 ) then!   not needed because there's always just one scalar line
!                             ThePrimAmp%FermionLines = 2
!                             ThePrimAmp%FermLine2In = Vertex
!                    elseif( ThePrimAmp%FermLine2Out.eq.0 ) then
!                             ThePrimAmp%FermLine2Out = Vertex
!                             do k=ThePrimAmp%FermLine2In+1,ThePrimAmp%FermLine2Out
!                                 ThePrimAmp%IntPart(k)%PartType = 0
!                             enddo
!                             do k=ThePrimAmp%FermLine2Out+1,NumExtParticles
!                                 ThePrimAmp%IntPart(k)%PartType = -abs(ThePrimAmp%FermLoopPart)
!                             enddo
                    else
                          call Error("something's missing here")
                   endif

               elseif( ThePrimamp%AmpType.eq.3 ) then
                       if( ThePrimAmp%FermLine2In.eq.0 ) then
                          ThePrimAmp%FermionLines = 2
                          ThePrimAmp%FermLine2In = Vertex
                       elseif( ThePrimAmp%FermLine2Out.eq.0 ) then
                          ThePrimAmp%FermLine2Out = Vertex
                          ThePrimAmp%IntPart(Propa)%PartType = ThePrimAmp%IntPart(ThePrimAmp%FermLine2In)%PartType
                          do k=ThePrimAmp%FermLine2In+1,ThePrimAmp%FermLine2Out
                              ThePrimAmp%IntPart(k)%PartType = 0
                          enddo
                       elseif( ThePrimAmp%FermLine1Out.eq.0 ) then
                           ThePrimAmp%FermLine1Out = Vertex
                           ThePrimAmp%IntPart(Propa)%PartType = Glu_
                       endif

               elseif( ThePrimamp%AmpType.eq.4 ) then
                       if( ThePrimAmp%FermLine1Out.eq.0 ) then
                           ThePrimAmp%FermLine1Out = Vertex
                           do k=ThePrimAmp%FermLine1In+1,ThePrimAmp%FermLine1Out
                              ThePrimAmp%IntPart(k)%PartType = 0
                           enddo
                       elseif( ThePrimAmp%FermLine2In.eq.0 ) then
                           ThePrimAmp%FermionLines = 2
                           ThePrimAmp%FermLine2In = Vertex
                            ThePrimAmp%IntPart(Propa)%PartType = Glu_
                            do k=ThePrimAmp%FermLine1Out+1,ThePrimAmp%FermLine2In
                                ThePrimAmp%IntPart(k)%PartType = -ExtPartType
                            enddo
                            ThePrimAmp%IntPart(1)%PartType = -ExtPartType
                       elseif( ThePrimAmp%FermLine2Out.eq.0 ) then
                            ThePrimAmp%FermLine2Out = Vertex
                            do k=ThePrimAmp%FermLine2Out+1,NumExtParticles
                                ThePrimAmp%IntPart(k)%PartType = ExtPartType
                            enddo
                       endif
               endif

            elseif( (ExtPartType .eq. Pho_) .or. (ExtPartType .eq. Z0_) .or. (ExtPartType .eq. Hig_) ) then
               ThePrimAmp%IntPart(Propa)%PartType = ThePrimAmp%IntPart(PropaMinus1)%PartType  &
                                                  + sign(1,ThePrimAmp%IntPart(PropaMinus1)%PartType)*1000!  incr.parttype by 1000 to take track of where the z is emitted, important for rejecting certain cuts
               ColorLessParticles = .true.                                                               !  this will be reset at the end of this subroutine

            elseif( ExtPartType .eq. Wp_ ) then
               ThePrimAmp%IntPart(Propa)%PartType = abs( ThePrimAmp%IntPart(PropaMinus1)%PartType -1)
               ColorLessParticles = .true.

            elseif( ExtPartType .eq. Wm_ ) then
               ThePrimAmp%IntPart(Propa)%PartType = abs( ThePrimAmp%IntPart(PropaMinus1)%PartType +1)
               ColorLessParticles = .true.
            endif
! print *, "propa",Propa,ThePrimAmp%IntPart(Propa)%PartType; !pause

         enddo! Vertex

!          print *, "check1",ThePrimamp%AmpType
!          print *, ThePrimAmp%FermLine1In,ThePrimAmp%FermLine1Out
!          print *, ThePrimAmp%FermLine2In,ThePrimAmp%FermLine2Out
!          print *, ThePrimAmp%ScaLine1In,ThePrimAmp%ScaLine1Out
!          pause

         do Propa=1,NumExtParticles
            if( ThePrimAmp%IntPart(Propa)%PartType .eq. 99 ) call Error("internal particle type is 99")
            ThePrimAmp%IntPart(Propa)%Mass  = GetMass( mod(ThePrimAmp%IntPart(Propa)%PartType,1000) )! mod(..,1000) because of Z0_ condition above
            ThePrimAmp%IntPart(Propa)%Mass2 = (ThePrimAmp%IntPart(Propa)%Mass)**2
            ThePrimAmp%IntPart(Propa)%ExtRef = -1
            if( IsAScalar(ExtParticle( ThePrimAmp%ExtLine(Propa) )%PartType) .and. ThePrimAmp%ScaLine1In.eq.0 ) then! checking if there are scalars
                    ThePrimAmp%ScaLine1In = ThePrimAmp%FermLine1In
                    ThePrimAmp%ScaLine1Out= ThePrimAmp%FermLine1Out
                    if( ThePrimAmp%FermLine2In.ne.0 ) then! checking if there are scalars+fermions
                        ThePrimAmp%FermLine1In  = ThePrimAmp%FermLine2In
                        ThePrimAmp%FermLine1Out = ThePrimAmp%FermLine2Out
                        ThePrimAmp%FermLine2In  = 0
                        ThePrimAmp%FermLine2Out = 0
                        ThePrimAmp%FermionLines = 1
                        ThePrimAmp%ScalarLines  = 1
                    else
                        ThePrimAmp%FermLine1In  = 0
                        ThePrimAmp%FermLine1Out = 0
                        ThePrimAmp%FermLine2In  = 0
                        ThePrimAmp%FermLine2Out = 0
                        ThePrimAmp%FermionLines = 0
                        ThePrimAmp%ScalarLines  = 1
                    endif
            endif
         enddo
!        set number of possible insertions of colorless particles into quark lines
!          if ( ColorLessParticles ) then
!             ThePrimAmp%NumInsertions1 = ThePrimAmp%FermLine1Out - ThePrimAmp%FermLine1In - 1
!             if( ThePrimAmp%FermionLines .eq. 2 ) then
!                ThePrimAmp%NumInsertions2 = ThePrimAmp%FermLine2Out - ThePrimAmp%FermLine2In - 1
!             endif
!          endif


!          print *, "check2",ThePrimamp%AmpType
!          print *, ThePrimAmp%FermLine1In,ThePrimAmp%FermLine1Out
!          print *, ThePrimAmp%FermLine2In,ThePrimAmp%FermLine2Out
!          print *, ThePrimAmp%ScaLine1In,ThePrimAmp%ScaLine1Out
!          pause

         call InitUCuts(ThePrimAmp)
!          print *, 'cuts inited'
      enddo! NPrimAmp

!      print *, 'calling remove dupl cuts'
! this ONLY finds the usual duplicates, not the unusual ones that we encounter in the fermion loop primitives     
!     call remove_duplicate_cuts()
     call remove_duplicate_cuts_better()
! find subtractions     

     call FindSubtractions()
! this removes the unusual duplicates that we find in fermion loops. 
! In addition, the subtractions from these duplicate cuts (found above) are inherited by the one cut that survives
!     print *, 'remove_cyclic_duplicates'
!     call remove_cyclic_duplicates()

!   undoing +/- 1000 required for Z0 couplings
    do NPrimAmp=1,NumPrimAmps
       do Propa=1,NumExtParticles
           PrimAmps(NPrimAmp)%IntPart(Propa)%PartType = mod( PrimAmps(NPrimAmp)%IntPart(Propa)%PartType  , 1000)
       enddo
    enddo




! !! RR printout to check id of duplicates !!
!     print *, ' PRINTOUT FOR DUPLICATES'
! !    pause
!     do NPrimAmp=1,NumPrimAmps
!        print *, '-------------------------'
!        print *, '   Primitive ', NPrimAmp
!        print *, '-------------------------'
!        do NPoint=1,5
!           print *, 'number of cuts = ', NPoint
!           do NCut=1,PrimAmps(NPrimAmp)%UCuts(NPoint)%NumCuts
!              print *, ' cuts: ', NCut, PrimAmps(NPrimAmp)%UCuts(NPoint)%CutProp(NCut,1:NPoint),  PrimAmps(NPrimAmp)%UCuts(NPoint)%skip(NCut)
! !             print *, 'skip ?',  PrimAmps(NPrimAmp)%UCuts(NPoint)%skip(NCut)
!           enddo
!        enddo
!     enddo
! !    pause
! ! RR printout ends here

ENDIF

RETURN
END SUBROUTINE






SUBROUTINE SetKirill(ThePrimAmp)
use ModMisc
use ModParameters
implicit none
integer :: Vertex,Propa,PropaMinus1,ExtPartType,NPrimAmp,k
integer :: AllocStatus,counter,counterQ,counterG,QuarkPos(1:6),NPart
logical :: ColorLessParticles
type(PrimitiveAmplitude) :: ThePrimAmp
type(BornAmplitude),pointer :: TheBornAmp
type(TreeProcess),pointer :: TheTree
integer :: h1,h2,h3,h4,h5,h6
complex(8) e(1:NumExtParticles,1:4)
integer :: i
include 'misc/global_import'

!     conversion to kirills conv for last prim. ampl.
   NPoint = NumExtParticles

!      if(NumExtParticles.ge.4) then
!         h1=ExtParticle(1)%Helicity
!         h2=ExtParticle(2)%Helicity
!         h3=ExtParticle(3)%Helicity
!         h4=ExtParticle(4)%Helicity
!      endif
!      if(NumExtParticles.eq.5) then
! !         h5=ExtParticle(5)%Helicity
! !         print *, "set h5!"
!      endif
!      if(NumExtParticles.eq.6) then
! !         h6=ExtParticle(6)%Helicity
!           print *, "set h6!"
!      endif

      do i=1,NumExtParticles
         mom(i,1:4) = ExtParticle( ThePrimAmp%ExtLine(i) )%Mom(1:4)
         hel(i,1:4) = ExtParticle( ThePrimAmp%ExtLine(i) )%Pol(1:4)
      enddo


!       the list of ``propagator momenta''
      do i=1,4
         momline(1,i)=dcmplx(0d0,0d0)
         momline(2,i)=mom(1,i)
         momline(3,i)=mom(1,i)+mom(2,i)
         momline(4,i)=mom(1,i)+mom(2,i)+mom(3,i)
         momline(5,i)=mom(1,i)+mom(2,i)+mom(3,i)+mom(4,i)
         momline(6,i)=mom(1,i)+mom(2,i)+mom(3,i)+mom(4,i)+mom(5,i)
      enddo


   do Vertex=1,NumExtParticles
            Propa       = Vertex + 1
            PropaMinus1 = Propa - 1
            ExtPartType = ExtParticle( ThePrimAmp%ExtLine(Vertex) )%PartType
            if( Vertex .eq. NumExtParticles ) then
               Propa       = 1
               PropaMinus1 = NumExtParticles
            endif

      if(ExtPartType.eq.Top_ .or. ExtPartType.eq.ATop_ ) then
         Lab_ex(Vertex)='top'
      elseif(ExtPartType.eq.Bot_ .or. ExtPartType.eq.ABot_ ) then
         Lab_ex(Vertex)='bot'
      elseif(ExtPartType.eq.Chm_ .or. ExtPartType.eq.AChm_ ) then
         Lab_ex(Vertex)='chm'
      elseif(ExtPartType.eq.Str_ .or. ExtPartType.eq.AStr_ ) then
         Lab_ex(Vertex)='str'
      elseif(ExtPartType.eq.Glu_ ) then
         Lab_ex(Vertex)='glu'
      elseif(ExtPartType.eq.HTop_ .or. ExtPartType.eq.AHTop_ ) then! fix for HTop
         Lab_ex(Vertex)='bot'! bot because the label HTop is only used in closed T' fermion loops
      elseif(ExtPartType.eq.STop_ .or. ExtPartType.eq.ASTop_ ) then! fix for STop
         Lab_ex(Vertex)='sto'
      elseif(ExtPartType.eq.Z0_ .or. ExtPartType.eq.Pho_ .or. ExtPartType .eq. Hig_) then
         Lab_ex(Vertex)='zee'
      

      else
         print *, "error in kirills conv, ExtPartType=", ExtPartType
      endif

      if( ThePrimAmp%IntPart(Propa)%PartType.eq.Top_ .or. ThePrimAmp%IntPart(Propa)%PartType.eq.ATop_ ) then
         Lab_in(Propa)='top'
      elseif( ThePrimAmp%IntPart(Propa)%PartType.eq.Bot_ .or. ThePrimAmp%IntPart(Propa)%PartType.eq.ABot_ ) then
         Lab_in(Propa)='bot'
      elseif( ThePrimAmp%IntPart(Propa)%PartType.eq.Chm_ .or. ThePrimAmp%IntPart(Propa)%PartType.eq.AChm_ ) then
         Lab_in(Propa)='chm'
      elseif( ThePrimAmp%IntPart(Propa)%PartType.eq.Str_ .or. ThePrimAmp%IntPart(Propa)%PartType.eq.AStr_ ) then
         Lab_in(Propa)='str'
      elseif( ThePrimAmp%IntPart(Propa)%PartType.eq.Glu_ ) then
         Lab_in(Propa)='glu'
      elseif( ThePrimAmp%IntPart(Propa)%PartType.eq.HTop_ .or. ThePrimAmp%IntPart(Propa)%PartType.eq.AHTop_ ) then
         Lab_in(Propa)='bot'! bot because the label HTop is only used in closed T' fermion loops
      elseif( ThePrimAmp%IntPart(Propa)%PartType.eq.STop_ .or. ThePrimAmp%IntPart(Propa)%PartType.eq.ASTop_ ) then
         Lab_in(Propa)='sto'
      elseif( ThePrimAmp%IntPart(Propa)%PartType.eq.SBot_ .or. ThePrimAmp%IntPart(Propa)%PartType.eq.ASBot_ ) then
         Lab_in(Propa)='sbo'
      else
         Lab_in(Propa)='notset'
      endif
  enddo

       N5=ThePrimAmp%UCuts(5)%NumCuts
       N4=ThePrimAmp%UCuts(4)%NumCuts
       N3=ThePrimAmp%UCuts(3)%NumCuts
       N2=ThePrimAmp%UCuts(2)%NumCuts
       N1=ThePrimAmp%UCuts(1)%NumCuts

       do k=1,N5
         Lc5(k,1)=ThePrimAmp%UCuts(5)%CutProp(k,1)
         Lc5(k,2)=ThePrimAmp%UCuts(5)%CutProp(k,2)
         Lc5(k,3)=ThePrimAmp%UCuts(5)%CutProp(k,3)
         Lc5(k,4)=ThePrimAmp%UCuts(5)%CutProp(k,4)
         Lc5(k,5)=ThePrimAmp%UCuts(5)%CutProp(k,5)
       enddo
       do k=1,N4
         Lc4(k,1)=ThePrimAmp%UCuts(4)%CutProp(k,1)
         Lc4(k,2)=ThePrimAmp%UCuts(4)%CutProp(k,2)
         Lc4(k,3)=ThePrimAmp%UCuts(4)%CutProp(k,3)
         Lc4(k,4)=ThePrimAmp%UCuts(4)%CutProp(k,4)
       enddo
       do k=1,N3
         Lc3(k,1)=ThePrimAmp%UCuts(3)%CutProp(k,1)
         Lc3(k,2)=ThePrimAmp%UCuts(3)%CutProp(k,2)
         Lc3(k,3)=ThePrimAmp%UCuts(3)%CutProp(k,3)
       enddo
       do k=1,N2
         Lc2(k,1)=ThePrimAmp%UCuts(2)%CutProp(k,1)
         Lc2(k,2)=ThePrimAmp%UCuts(2)%CutProp(k,2)
       enddo
       do k=1,N1
         Lc1(k,1)=ThePrimAmp%UCuts(1)%CutProp(k,1)
       enddo

return
END SUBROUTINE




SUBROUTINE InitUCuts(ThePrimAmp)
use ModMisc
use ModParameters
implicit none
integer :: AllocStatus,NCut
integer :: i1,i2,i3,i4,i5,j
type(PrimitiveAmplitude),target :: ThePrimAmp
integer :: NumVertPart,NPart,NPoint,NTree,LastQuark
logical :: MasslessExtLeg,MasslessIntParticles
integer :: QuarkPos(1:6),counter,counterQ,counterG,counterS,counterV
type(TreeProcess),pointer :: TheTree


   if( ThePrimAmp%AmpType.eq.1 ) then
      ThePrimAmp%NPoint = NumExtParticles
   elseif( ThePrimAmp%AmpType.eq.2 ) then
      ThePrimAmp%NPoint = NumExtParticles-(ThePrimAmp%FermLine1Out-ThePrimAmp%FermLine1In)-(ThePrimAmp%FermLine2Out-ThePrimAmp%FermLine2In)-(ThePrimAmp%ScaLine1Out-ThePrimAmp%ScaLine1In)
   elseif( ThePrimAmp%AmpType.eq.3 .and. ThePrimAmp%ScaLine1In.eq.0) then
      ThePrimAmp%NPoint = NumExtParticles-(ThePrimAmp%FermLine2Out-ThePrimAmp%FermLine2In)
   elseif( ThePrimAmp%AmpType.eq.3 .and. ThePrimAmp%ScaLine1In.ne.0) then
      ThePrimAmp%NPoint = NumExtParticles-(ThePrimAmp%FermLine1Out-ThePrimAmp%FermLine1In)
   elseif( ThePrimAmp%AmpType.eq.4 .and. ThePrimAmp%ScaLine1In.eq.0) then
      ThePrimAmp%NPoint = NumExtParticles-(ThePrimAmp%FermLine1Out-ThePrimAmp%FermLine1In)
   elseif( ThePrimAmp%AmpType.eq.4 .and. ThePrimAmp%ScaLine1In.ne.0) then
      ThePrimAmp%NPoint = NumExtParticles-(ThePrimAmp%ScaLine1Out-ThePrimAmp%ScaLine1In)
   endif


!  set number of cuts
   ThePrimAmp%UCuts(5)%CutType = 5
   if ( NumExtParticles .ge. 5) then
      ThePrimAmp%UCuts(5)%NumCuts = Binomial(ThePrimAmp%NPoint,5)
   else
      ThePrimAmp%UCuts(5)%NumCuts = 0
   endif

   ThePrimAmp%UCuts(4)%CutType = 4
   ThePrimAmp%UCuts(4)%NumCuts = Binomial(ThePrimAmp%NPoint,4)

   ThePrimAmp%UCuts(3)%CutType = 3
   ThePrimAmp%UCuts(3)%NumCuts = Binomial(ThePrimAmp%NPoint,3)

   ThePrimAmp%UCuts(2)%CutType = 2
   ThePrimAmp%UCuts(2)%NumCuts = Binomial(ThePrimAmp%NPoint,2)

   ThePrimAmp%UCuts(1)%CutType = 1
   ThePrimAmp%UCuts(1)%NumCuts = Binomial(ThePrimAmp%NPoint,1)


!  allocate memory for CutProp
   allocate( ThePrimAmp%UCuts(5)%CutProp(1:ThePrimAmp%UCuts(5)%NumCuts,1:5), stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(5)")
   allocate( ThePrimAmp%UCuts(5)%Coeff(1:ThePrimAmp%UCuts(5)%NumCuts,0:0),     stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(5)")
   allocate( ThePrimAmp%UCuts(5)%Coeff_128(1:ThePrimAmp%UCuts(5)%NumCuts,0:0),     stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(5)")
   allocate( ThePrimAmp%UCuts(5)%KMom(1:ThePrimAmp%UCuts(5)%NumCuts,1:4,1:4) )
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in KMom 5")

   allocate( ThePrimAmp%UCuts(4)%CutProp(1:ThePrimAmp%UCuts(4)%NumCuts,1:4), stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(4)")
   allocate( ThePrimAmp%UCuts(4)%Coeff(1:ThePrimAmp%UCuts(4)%NumCuts,0:4),   stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(4)")
   allocate( ThePrimAmp%UCuts(4)%Coeff_128(1:ThePrimAmp%UCuts(4)%NumCuts,0:4),   stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(4)")
   allocate( ThePrimAmp%UCuts(4)%KMom(1:ThePrimAmp%UCuts(4)%NumCuts,1:3,1:4) )
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in KMom 4")
   allocate( ThePrimAmp%UCuts(4)%NMom(1:ThePrimAmp%UCuts(4)%NumCuts,1:1,1:4) )
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in NMom 4")

   allocate( ThePrimAmp%UCuts(3)%CutProp(1:ThePrimAmp%UCuts(3)%NumCuts,1:3), stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(3)")
   allocate( ThePrimAmp%UCuts(3)%Coeff(1:ThePrimAmp%UCuts(3)%NumCuts,0:9),   stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(3)")
   allocate( ThePrimAmp%UCuts(3)%Coeff_128(1:ThePrimAmp%UCuts(3)%NumCuts,0:9),   stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(3)")
   allocate( ThePrimAmp%UCuts(3)%KMom(1:ThePrimAmp%UCuts(3)%NumCuts,1:2,1:4) )
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in KMom 3")
   allocate( ThePrimAmp%UCuts(3)%NMom(1:ThePrimAmp%UCuts(3)%NumCuts,1:2,1:4) )
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in NMom 3")

   allocate( ThePrimAmp%UCuts(2)%CutProp(1:ThePrimAmp%UCuts(2)%NumCuts,1:2), stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(2)")
   allocate( ThePrimAmp%UCuts(2)%Coeff(1:ThePrimAmp%UCuts(2)%NumCuts,0:9),   stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(2)")
   allocate( ThePrimAmp%UCuts(2)%Coeff_128(1:ThePrimAmp%UCuts(2)%NumCuts,0:9),   stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(2)")
   allocate( ThePrimAmp%UCuts(2)%KMom(1:ThePrimAmp%UCuts(2)%NumCuts,1:1,1:4) )
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in KMom 2")
   allocate( ThePrimAmp%UCuts(2)%NMom(1:ThePrimAmp%UCuts(2)%NumCuts,1:3,1:4) )
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in NMom 2")

   allocate( ThePrimAmp%UCuts(1)%CutProp(1:ThePrimAmp%UCuts(1)%NumCuts,1:1), stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(1)")
   allocate( ThePrimAmp%UCuts(1)%Coeff(1:ThePrimAmp%UCuts(1)%NumCuts,0:0),     stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(1)")
   allocate( ThePrimAmp%UCuts(1)%Coeff_128(1:ThePrimAmp%UCuts(1)%NumCuts,0:0),     stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(1)")

!    print *, 'allocate skip'
   allocate( ThePrimAmp%UCuts(5)%skip(1:ThePrimAmp%UCuts(5)%NumCuts),stat=AllocStatus )
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in skip 5")
   allocate( ThePrimAmp%UCuts(4)%skip(1:ThePrimAmp%UCuts(4)%NumCuts),stat=AllocStatus )
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in skip 4")
   allocate( ThePrimAmp%UCuts(3)%skip(1:ThePrimAmp%UCuts(3)%NumCuts),stat=AllocStatus )
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in skip 3")
   allocate( ThePrimAmp%UCuts(2)%skip(1:ThePrimAmp%UCuts(2)%NumCuts),stat=AllocStatus )
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in skip 2")
   allocate( ThePrimAmp%UCuts(1)%skip(1:ThePrimAmp%UCuts(1)%NumCuts),stat=AllocStatus )
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in skip 1")
!    print *, 'done allocating skip'

! allocate tagcuts
   allocate( ThePrimAmp%UCuts(5)%tagcuts(1:ThePrimAmp%UCuts(5)%NumCuts),   stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(5)")
   allocate( ThePrimAmp%UCuts(4)%tagcuts(1:ThePrimAmp%UCuts(4)%NumCuts),   stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(4)")
   allocate( ThePrimAmp%UCuts(3)%tagcuts(1:ThePrimAmp%UCuts(3)%NumCuts),   stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(3)")
   allocate( ThePrimAmp%UCuts(2)%tagcuts(1:ThePrimAmp%UCuts(2)%NumCuts),   stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(2)")
   allocate( ThePrimAmp%UCuts(1)%tagcuts(1:ThePrimAmp%UCuts(1)%NumCuts),   stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(1)")
!  now set tagcuts to -1 for all values -- only needed for doub cut anyway
   ThePrimAmp%UCuts(5)%tagcuts(1:ThePrimAmp%UCuts(5)%NumCuts)=-1
   ThePrimAmp%UCuts(4)%tagcuts(1:ThePrimAmp%UCuts(4)%NumCuts)=-1
   ThePrimAmp%UCuts(3)%tagcuts(1:ThePrimAmp%UCuts(3)%NumCuts)=-1
   ThePrimAmp%UCuts(2)%tagcuts(1:ThePrimAmp%UCuts(2)%NumCuts)=-1
   ThePrimAmp%UCuts(1)%tagcuts(1:ThePrimAmp%UCuts(1)%NumCuts)=-1
!    print *, 'done tagcuts'

!  init pentcuts
   allocate(ThePrimAmp%UCuts(5)%TreeProcess(1:ThePrimAmp%UCuts(5)%NumCuts,1:5), stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(5)%TreeProcess(ThePrimAmp%UCuts(5)%NumCuts,5)")
   NCut = 1
   do i1 = 1,    NumExtParticles-4
   do i2 = i1+1, NumExtParticles-3
   do i3 = i2+1, NumExtParticles-2
   do i4 = i3+1, NumExtParticles-1
   do i5 = i4+1, NumExtParticles

!          skip cuts that are marked for discarding
           if( mod(ThePrimAmp%IntPart(i1)%PartType,1000) .eq. 0 ) cycle
           if( mod(ThePrimAmp%IntPart(i2)%PartType,1000) .eq. 0 ) cycle
           if( mod(ThePrimAmp%IntPart(i3)%PartType,1000) .eq. 0 ) cycle
           if( mod(ThePrimAmp%IntPart(i4)%PartType,1000) .eq. 0 ) cycle
           if( mod(ThePrimAmp%IntPart(i5)%PartType,1000) .eq. 0 ) cycle

!          set tree processes
!          vertex 1
           TheTree => ThePrimAmp%UCuts(5)%TreeProcess(NCut,1)
           NumVertPart = i2-i1
           TheTree%NumPart = NumVertPart+2
           allocate( TheTree%PartRef(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartRef 5-1")
           allocate( TheTree%PartType(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartType 5-1")
!          set particle reference (wrt.prim.amp) and flavor
           TheTree%PartRef(1) = i1
           TheTree%PartType(1) = mod(ThePrimAmp%IntPart(i1)%PartType,1000)
           TheTree%PartRef(NumVertPart+2) = i2
           TheTree%PartType(NumVertPart+2) = ChargeConj( mod(ThePrimAmp%IntPart(i2)%PartType,1000)   )
           do NPart=0,NumVertPart-1
               TheTree%PartRef(NPart+2) = i1+NPart
               TheTree%PartType(NPart+2) = ExtParticle( ThePrimAmp%ExtLine(i1+NPart) )%PartType
           enddo

!          vertex 2
           TheTree => ThePrimAmp%UCuts(5)%TreeProcess(NCut,2)
           NumVertPart = i3-i2
           TheTree%NumPart = NumVertPart+2
           allocate( TheTree%PartRef(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartRef 5-2")
           allocate( TheTree%PartType(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartType 5-2")
!          set particle reference (wrt.prim.amp) and flavor
           TheTree%PartRef(1) = i2
           TheTree%PartType(1) = mod(ThePrimAmp%IntPart(i2)%PartType,1000)
           TheTree%PartRef(NumVertPart+2) = i3
           TheTree%PartType(NumVertPart+2) = ChargeConj( mod(ThePrimAmp%IntPart(i3)%PartType,1000)  )
           do NPart=0,NumVertPart-1
               TheTree%PartRef(NPart+2) = i2+NPart
               TheTree%PartType(NPart+2) = ExtParticle( ThePrimAmp%ExtLine(i2+NPart) )%PartType
           enddo


!          vertex 3
           TheTree => ThePrimAmp%UCuts(5)%TreeProcess(NCut,3)
           NumVertPart = i4-i3
           TheTree%NumPart = NumVertPart+2
           allocate( TheTree%PartRef(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartRef 5-3")
           allocate( TheTree%PartType(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartType 5-3")
!          set particle reference (wrt.prim.amp) and flavor
           TheTree%PartRef(1) = i3
           TheTree%PartType(1) = mod(ThePrimAmp%IntPart(i3)%PartType,1000)
           TheTree%PartRef(NumVertPart+2) = i4
           TheTree%PartType(NumVertPart+2) = ChargeConj( mod(ThePrimAmp%IntPart(i4)%PartType,1000)  )
           do NPart=0,NumVertPart-1
               TheTree%PartRef(NPart+2) = i3+NPart
               TheTree%PartType(NPart+2) = ExtParticle( ThePrimAmp%ExtLine(i3+NPart) )%PartType
           enddo


!          vertex 4
           TheTree => ThePrimAmp%UCuts(5)%TreeProcess(NCut,4)
           NumVertPart = i5-i4
           TheTree%NumPart = NumVertPart+2
           allocate( TheTree%PartRef(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartRef 5-4")
           allocate( TheTree%PartType(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartType 5-4")
!          set particle reference (wrt.prim.amp) and flavor
           TheTree%PartRef(1) = i4
           TheTree%PartType(1) = mod(ThePrimAmp%IntPart(i4)%PartType,1000)
           TheTree%PartRef(NumVertPart+2) = i5
           TheTree%PartType(NumVertPart+2) = ChargeConj( mod(ThePrimAmp%IntPart(i5)%PartType,1000)  )
           do NPart=0,NumVertPart-1
               TheTree%PartRef(NPart+2) = i4+NPart
               TheTree%PartType(NPart+2) = ExtParticle( ThePrimAmp%ExtLine(i4+NPart) )%PartType
           enddo


!          vertex 5
           TheTree => ThePrimAmp%UCuts(5)%TreeProcess(NCut,5)
           NumVertPart = i1-(i5-NumExtParticles)
           TheTree%NumPart = NumVertPart+2
           allocate( TheTree%PartRef(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartRef 5-5")
           allocate( TheTree%PartType(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartType 5-5")
!          set particle reference (wrt.prim.amp) and flavor
           TheTree%PartRef(1) = i5
           TheTree%PartType(1) = mod(ThePrimAmp%IntPart(i5)%PartType,1000)
           TheTree%PartRef(NumVertPart+2) = i1
           TheTree%PartType(NumVertPart+2) = ChargeConj( mod(ThePrimAmp%IntPart(i1)%PartType,1000)  )
           do NPart=0,NumVertPart-1
             if( i5+NPart.le.NumExtParticles ) then
                  TheTree%PartRef(NPart+2) = i5+NPart
                  TheTree%PartType(NPart+2) = ExtParticle( ThePrimAmp%ExtLine(i5+NPart) )%PartType
               else
                  TheTree%PartRef(NPart+2) = i5+NPart-NumExtParticles
                  TheTree%PartType(NPart+2) = ExtParticle( ThePrimAmp%ExtLine(i5+NPart-NumExtParticles) )%PartType
               endif
           enddo

           ThePrimAmp%UCuts(5)%CutProp(NCut,1) = i1
           ThePrimAmp%UCuts(5)%CutProp(NCut,2) = i2
           ThePrimAmp%UCuts(5)%CutProp(NCut,3) = i3
           ThePrimAmp%UCuts(5)%CutProp(NCut,4) = i4
           ThePrimAmp%UCuts(5)%CutProp(NCut,5) = i5
!            print *, 'cuts:', NCut, ThePrimAmp%UCuts(5)%CutProp(NCut,1:5)
!            print *, 'tree 1:', ThePrimAmp%UCuts(5)%TreeProcess(NCut,1)%PartType(1:TheTree%NumPart)
!            print *, 'tree 2:', ThePrimAmp%UCuts(5)%TreeProcess(NCut,2)%PartType(1:TheTree%NumPart)
!            print *, 'tree 3:', ThePrimAmp%UCuts(5)%TreeProcess(NCut,3)%PartType(1:TheTree%NumPart)
!            print *, 'tree 4:', ThePrimAmp%UCuts(5)%TreeProcess(NCut,4)%PartType(1:TheTree%NumPart)
!            print *, 'tree 5:', ThePrimAmp%UCuts(5)%TreeProcess(NCut,5)%PartType(1:TheTree%NumPart)
           
           
           NCut = NCut + 1
   enddo
   enddo
   enddo
   enddo
   enddo
   if ( NCut-1 .ne. ThePrimAmp%UCuts(5)%NumCuts ) call Error("Something went wrong while setting pent-cuts.")




!  init quadcuts
   allocate(ThePrimAmp%UCuts(4)%TreeProcess(1:ThePrimAmp%UCuts(4)%NumCuts,1:4), stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(4)%TreeProcess(ThePrimAmp%UCuts(4)%NumCuts,4).")
   NCut = 1
   do i2 = 1, NumExtParticles-3
   do i3 = i2+1, NumExtParticles-2
   do i4 = i3+1, NumExtParticles-1
   do i5 = i4+1, NumExtParticles


!          skip cuts that are marked for discarding
           if( mod(ThePrimAmp%IntPart(i2)%PartType,1000) .eq. 0 ) cycle
           if( mod(ThePrimAmp%IntPart(i3)%PartType,1000) .eq. 0 ) cycle
           if( mod(ThePrimAmp%IntPart(i4)%PartType,1000) .eq. 0 ) cycle
           if( mod(ThePrimAmp%IntPart(i5)%PartType,1000) .eq. 0 ) cycle

!          set tree processes
!          vertex 1
           TheTree => ThePrimAmp%UCuts(4)%TreeProcess(NCut,1)
           NumVertPart = i3-i2
           TheTree%NumPart = NumVertPart+2
           allocate( TheTree%PartRef(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartRef 4-1")
           allocate( TheTree%PartType(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartType 4-1")
!          set particle reference (wrt.prim.amp) and flavor
           TheTree%PartRef(1) = i2
           TheTree%PartType(1) = mod(ThePrimAmp%IntPart(i2)%PartType,1000)
           TheTree%PartRef(NumVertPart+2) = i3
           TheTree%PartType(NumVertPart+2) = ChargeConj( mod(ThePrimAmp%IntPart(i3)%PartType,1000)  )
           do NPart=0,NumVertPart-1
               TheTree%PartRef(NPart+2) = i2+NPart
               TheTree%PartType(NPart+2) = ExtParticle( ThePrimAmp%ExtLine(i2+NPart) )%PartType
           enddo

!          vertex 2
           TheTree => ThePrimAmp%UCuts(4)%TreeProcess(NCut,2)
           NumVertPart = i4-i3
           TheTree%NumPart = NumVertPart+2
           allocate( TheTree%PartRef(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartRef 4-2")
           allocate( TheTree%PartType(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartType 4-2")
!          set particle reference (wrt.prim.amp) and flavor
           TheTree%PartRef(1) = i3
           TheTree%PartType(1) = mod(ThePrimAmp%IntPart(i3)%PartType,1000)
           TheTree%PartRef(NumVertPart+2) = i4
           TheTree%PartType(NumVertPart+2) = ChargeConj( mod(ThePrimAmp%IntPart(i4)%PartType,1000)  )
           do NPart=0,NumVertPart-1
               TheTree%PartRef(NPart+2) = i3+NPart
               TheTree%PartType(NPart+2) = ExtParticle( ThePrimAmp%ExtLine(i3+NPart) )%PartType
           enddo

!          vertex 3
           TheTree => ThePrimAmp%UCuts(4)%TreeProcess(NCut,3)
           NumVertPart = i5-i4
           TheTree%NumPart = NumVertPart+2
           allocate( TheTree%PartRef(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartRef 4-3")
           allocate( TheTree%PartType(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartType 4-3")
!          set particle reference (wrt.prim.amp) and flavor
           TheTree%PartRef(1) = i4
           TheTree%PartType(1) = mod(ThePrimAmp%IntPart(i4)%PartType,1000)
           TheTree%PartRef(NumVertPart+2) = i5
           TheTree%PartType(NumVertPart+2) = ChargeConj(  mod(ThePrimAmp%IntPart(i5)%PartType,1000)  )
           do NPart=0,NumVertPart-1
               TheTree%PartRef(NPart+2) = i4+NPart
               TheTree%PartType(NPart+2) = ExtParticle( ThePrimAmp%ExtLine(i4+NPart) )%PartType
           enddo

!          vertex 4
           TheTree => ThePrimAmp%UCuts(4)%TreeProcess(NCut,4)
           NumVertPart = i2-(i5-NumExtParticles)
           TheTree%NumPart = NumVertPart+2
           allocate( TheTree%PartRef(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartRef 4-4")
           allocate( TheTree%PartType(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartType 4-4")
!          set particle reference (wrt.prim.amp) and flavor
           TheTree%PartRef(1) = i5
           TheTree%PartType(1) = mod(ThePrimAmp%IntPart(i5)%PartType,1000)
           TheTree%PartRef(NumVertPart+2) = i2
           TheTree%PartType(NumVertPart+2) = ChargeConj(  mod(ThePrimAmp%IntPart(i2)%PartType,1000)   )
           do NPart=0,NumVertPart-1
               if( i5+NPart.le.NumExtParticles ) then
                  TheTree%PartRef(NPart+2) = i5+NPart
                  TheTree%PartType(NPart+2) = ExtParticle( ThePrimAmp%ExtLine(i5+NPart) )%PartType
               else
                  TheTree%PartRef(NPart+2) = i5+NPart-NumExtParticles
                  TheTree%PartType(NPart+2) = ExtParticle( ThePrimAmp%ExtLine(i5+NPart-NumExtParticles) )%PartType
               endif
           enddo

           ThePrimAmp%UCuts(4)%CutProp(NCut,1) = i2
           ThePrimAmp%UCuts(4)%CutProp(NCut,2) = i3
           ThePrimAmp%UCuts(4)%CutProp(NCut,3) = i4
           ThePrimAmp%UCuts(4)%CutProp(NCut,4) = i5
!            print *,'cuts', NCut, ThePrimAmp%UCuts(4)%CutProp(NCut,1:4)
!            print *, 'tree 1:', ThePrimAmp%UCuts(4)%TreeProcess(NCut,1)%PartType(1:ThePrimAmp%UCuts(4)%TreeProcess(NCut,1)%NumPart)
!            print *, 'tree 2:', ThePrimAmp%UCuts(4)%TreeProcess(NCut,2)%PartType(1:ThePrimAmp%UCuts(4)%TreeProcess(NCut,2)%NumPart)
!            print *, 'tree 3:', ThePrimAmp%UCuts(4)%TreeProcess(NCut,3)%PartType(1:ThePrimAmp%UCuts(4)%TreeProcess(NCut,3)%NumPart)
!            print *, 'tree 4:', ThePrimAmp%UCuts(4)%TreeProcess(NCut,4)%PartType(1:ThePrimAmp%UCuts(4)%TreeProcess(NCut,4)%NumPart)
           ThePrimAmp%UCuts(4)%CutProp(NCut,1) = i2
           NCut = NCut + 1
   enddo
   enddo
   enddo
   enddo

   if ( NCut-1 .ne. ThePrimAmp%UCuts(4)%NumCuts ) call Error("Something went wrong while setting quad-cuts.",ThePrimAmp%UCuts(4)%NumCuts)





!  init tripcuts
   allocate(ThePrimAmp%UCuts(3)%TreeProcess(1:ThePrimAmp%UCuts(3)%NumCuts,1:3), stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(3)%TreeProcess(ThePrimAmp%UCuts(3)%NumCuts,1:3).")
   NCut = 1
   do i3 = 1,    NumExtParticles-2
   do i4 = i3+1, NumExtParticles-1
   do i5 = i4+1, NumExtParticles

!          skip cuts that are marked for discarding
           if( mod(ThePrimAmp%IntPart(i3)%PartType,1000) .eq. 0 ) cycle
           if( mod(ThePrimAmp%IntPart(i4)%PartType,1000) .eq. 0 ) cycle
           if( mod(ThePrimAmp%IntPart(i5)%PartType,1000) .eq. 0 ) cycle

!          set tree processes
!          vertex 1
           TheTree => ThePrimAmp%UCuts(3)%TreeProcess(NCut,1)
           NumVertPart = i4-i3
           TheTree%NumPart = NumVertPart+2
           allocate( TheTree%PartRef(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartRef 3-1")
           allocate( TheTree%PartType(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartType 3-1")
!          set particle reference (wrt.prim.amp) and flavor
           TheTree%PartRef(1) = i3
           TheTree%PartType(1) = mod(ThePrimAmp%IntPart(i3)%PartType,1000)
           TheTree%PartRef(NumVertPart+2) = i4
           TheTree%PartType(NumVertPart+2) = ChargeConj(mod(ThePrimAmp%IntPart(i4)%PartType,1000) )
           do NPart=0,NumVertPart-1
               TheTree%PartRef(NPart+2) = i3+NPart
               TheTree%PartType(NPart+2) = ExtParticle( ThePrimAmp%ExtLine(i3+NPart) )%PartType
           enddo

!          vertex 2
           TheTree => ThePrimAmp%UCuts(3)%TreeProcess(NCut,2)
           NumVertPart = i5-i4
           TheTree%NumPart = NumVertPart+2
           allocate( TheTree%PartRef(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartRef 3-2")
           allocate( TheTree%PartType(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartType 3-2")
!          set particle reference (wrt.prim.amp) and flavor
           TheTree%PartRef(1) = i4
           TheTree%PartType(1) = mod(ThePrimAmp%IntPart(i4)%PartType,1000)
           TheTree%PartRef(NumVertPart+2) = i5
           TheTree%PartType(NumVertPart+2) = ChargeConj(mod(ThePrimAmp%IntPart(i5)%PartType,1000) )
           do NPart=0,NumVertPart-1
               TheTree%PartRef(NPart+2) = i4+NPart
               TheTree%PartType(NPart+2) = ExtParticle( ThePrimAmp%ExtLine(i4+NPart) )%PartType
           enddo

!          vertex 3
           TheTree => ThePrimAmp%UCuts(3)%TreeProcess(NCut,3)
           NumVertPart = i3-(i5-NumExtParticles)
           TheTree%NumPart = NumVertPart+2
           allocate( TheTree%PartRef(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartRef 3-3")
           allocate( TheTree%PartType(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartType 3-3")
!          set particle reference (wrt.prim.amp) and flavor
           TheTree%PartRef(1) = i5
           TheTree%PartType(1) = mod(ThePrimAmp%IntPart(i5)%PartType,1000)
           TheTree%PartRef(NumVertPart+2) = i3
           TheTree%PartType(NumVertPart+2) = ChargeConj(mod(ThePrimAmp%IntPart(i3)%PartType,1000) )
           do NPart=0,NumVertPart-1
               if( i5+NPart.le.NumExtParticles ) then
                  TheTree%PartRef(NPart+2) = i5+NPart
                  TheTree%PartType(NPart+2) = ExtParticle( ThePrimAmp%ExtLine(i5+NPart) )%PartType
               else
                  TheTree%PartRef(NPart+2) = i5+NPart-NumExtParticles
                  TheTree%PartType(NPart+2) = ExtParticle( ThePrimAmp%ExtLine(i5+NPart-NumExtParticles) )%PartType
               endif
           enddo

           ThePrimAmp%UCuts(3)%CutProp(NCut,1) = i3
           ThePrimAmp%UCuts(3)%CutProp(NCut,2) = i4
           ThePrimAmp%UCuts(3)%CutProp(NCut,3) = i5

!            print *, NCut, ThePrimAmp%UCuts(3)%CutProp(NCut,1:3)
!            print *, 'tree 1:', ThePrimAmp%UCuts(3)%TreeProcess(NCut,1)%PartType(1:ThePrimAmp%UCuts(3)%TreeProcess(NCut,1)%NumPart)
!            print *, 'tree 2:', ThePrimAmp%UCuts(3)%TreeProcess(NCut,2)%PartType(1:ThePrimAmp%UCuts(3)%TreeProcess(NCut,2)%NumPart)
!            print *, 'tree 3:', ThePrimAmp%UCuts(3)%TreeProcess(NCut,3)%PartType(1:ThePrimAmp%UCuts(3)%TreeProcess(NCut,3)%NumPart)
          

           NCut = NCut + 1
   enddo
   enddo
   enddo
   if ( NCut-1 .ne. ThePrimAmp%UCuts(3)%NumCuts ) call Error("Something went wrong while setting trip-cuts.")





!  set doub-cuts
   allocate(ThePrimAmp%UCuts(2)%TreeProcess(1:ThePrimAmp%UCuts(2)%NumCuts,1:2), stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(2)%TreeProcess(ThePrimAmp%UCuts(2)%NumCuts,1:2).")
   NCut = 1
   do i4 = 1,    NumExtParticles-1
   do i5 = i4+1, NumExtParticles

!          skip cuts that are marked for discarding
           if( mod(ThePrimAmp%IntPart(i4)%PartType,1000) .eq. 0 ) cycle
           if( mod(ThePrimAmp%IntPart(i5)%PartType,1000) .eq. 0 ) cycle

!          set tree processes
!          vertex 1
           TheTree => ThePrimAmp%UCuts(2)%TreeProcess(NCut,1)
           NumVertPart = i5-i4
           TheTree%NumPart = NumVertPart+2
           allocate( TheTree%PartRef(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartRef 2-1")
           allocate( TheTree%PartType(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartType 2-1")
!          set particle reference (wrt.prim.amp) and flavor
           TheTree%PartRef(1) = i4
           TheTree%PartType(1) = mod(ThePrimAmp%IntPart(i4)%PartType,1000)
           TheTree%PartRef(NumVertPart+2) = i5
           TheTree%PartType(NumVertPart+2) = ChargeConj(mod(ThePrimAmp%IntPart(i5)%PartType,1000) )
           do NPart=0,NumVertPart-1
               TheTree%PartRef(NPart+2) = i4+NPart
               TheTree%PartType(NPart+2) = ExtParticle( ThePrimAmp%ExtLine(i4+NPart) )%PartType
           enddo

!          check for massless external leg at vertex 1
           MasslessExtLeg = .false.
!            if( NumVertPart.eq.1 .and. ExtParticle( TheTree%PartRef(2) )%Mass .le. 1d-10 ) then
           if( NumVertPart.eq.1 .and. ExtParticle(  ThePrimAmp%ExtLine(TheTree%PartRef(2))   )%Mass .le. 1d-10 ) then
               MasslessExtLeg = .true.
           endif


!          vertex 2
           TheTree => ThePrimAmp%UCuts(2)%TreeProcess(NCut,2)
           NumVertPart = i4-(i5-NumExtParticles)
           TheTree%NumPart = NumVertPart+2
           allocate( TheTree%PartRef(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartRef 2-2")
           allocate( TheTree%PartType(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartType 2-2")
!          set particle reference (wrt.prim.amp) and flavor
           TheTree%PartRef(1) = i5
           TheTree%PartType(1) = mod(ThePrimAmp%IntPart(i5)%PartType,1000)
           TheTree%PartRef(NumVertPart+2) = i4
           TheTree%PartType(NumVertPart+2) = ChargeConj(mod(ThePrimAmp%IntPart(i4)%PartType,1000) )
           do NPart=0,NumVertPart-1
               if( i5+NPart.le.NumExtParticles ) then
                  TheTree%PartRef(NPart+2) = i5+NPart
                  TheTree%PartType(NPart+2) = ExtParticle( ThePrimAmp%ExtLine(i5+NPart) )%PartType
               else
                  TheTree%PartRef(NPart+2) = i5+NPart-NumExtParticles
                  TheTree%PartType(NPart+2) = ExtParticle( ThePrimAmp%ExtLine(i5+NPart-NumExtParticles) )%PartType
               endif
           enddo

!          check for massless external leg at vertex 2         
!           if( NumVertPart.eq.1 .and. ExtParticle( TheTree%PartRef(2) )%Mass .le. 1d-10 ) then
!            if( NumVertPart.eq.1 .and. ExtParticle(  ThePrimAmp%ExtLine(i5) )%Mass .le. 1d-10 ) then! RR bug fix? 
           if( NumVertPart.eq.1 .and. ExtParticle(  ThePrimAmp%ExtLine(TheTree%PartRef(2))   )%Mass .le. 1d-10 ) then  
               MasslessExtLeg = .true.
           endif

!          check for massless internal particles
           MasslessIntParticles = .false.
           if( ThePrimAmp%IntPart(i4)%Mass .le. 1d-10 .and. ThePrimAmp%IntPart(i5)%Mass .le. 1d-10 ) then
               MasslessIntParticles = .true.
           endif

! if( ThePrimAmp%AmpType.eq.2 ) then
!            print *, 'prim', ThePrimAmp%ExtLine(:)
!            print *, 'cuts', i4,i5
! !            print *, ExtParticle(ThePrimAmp%UCuts(2)%TreeProcess(NCut,1)%PartRef(2) )%Mass,  ExtParticle( ThePrimAmp%UCuts(2)%TreeProcess(NCut,2)%PartRef(2)  )%Mass 
!            print *, ExtParticle( ThePrimAmp%ExtLine( ThePrimAmp%UCuts(2)%TreeProcess(NCut,1)%PartRef(2)) )%Mass  , ExtParticle( ThePrimAmp%ExtLine( ThePrimAmp%UCuts(2)%TreeProcess(NCut,2)%PartRef(2) )  )%Mass    
! !            print *, 'tree 1:', ThePrimAmp%UCuts(2)%TreeProcess(NCut-1,1)%PartType(1:ThePrimAmp%UCuts(2)%TreeProcess(NCut-1,1)%NumPart)
! !            print *, 'tree 2:', ThePrimAmp%UCuts(2)%TreeProcess(NCut-1,2)%PartType(1:ThePrimAmp%UCuts(2)%TreeProcess(NCut-1,2)%NumPart)
! pause
! endif


!          check for massless bubbles
           if( MasslessExtLeg .and. MasslessIntParticles ) then
               deallocate( ThePrimAmp%UCuts(2)%TreeProcess(NCut,1)%PartRef )
               deallocate( ThePrimAmp%UCuts(2)%TreeProcess(NCut,1)%PartType )
               deallocate( ThePrimAmp%UCuts(2)%TreeProcess(NCut,2)%PartRef )
               deallocate( ThePrimAmp%UCuts(2)%TreeProcess(NCut,2)%PartType )
               ThePrimAmp%UCuts(2)%NumCuts = ThePrimAmp%UCuts(2)%NumCuts - 1
               cycle
           else
               ThePrimAmp%UCuts(2)%CutProp(NCut,1) = i4
               ThePrimAmp%UCuts(2)%CutProp(NCut,2) = i5
               NCut = NCut + 1
           endif

!            print *, 'prim', ThePrimAmp%ExtLine(:)
!            print *, 'cuts', i4,i5
!            print *, 'tree 1:', ThePrimAmp%UCuts(2)%TreeProcess(NCut-1,1)%PartType(1:ThePrimAmp%UCuts(2)%TreeProcess(NCut-1,1)%NumPart)
!            print *, 'tree 2:', ThePrimAmp%UCuts(2)%TreeProcess(NCut-1,2)%PartType(1:ThePrimAmp%UCuts(2)%TreeProcess(NCut-1,2)%NumPart)
! pause


   enddo
   enddo
   if ( NCut-1 .ne. ThePrimAmp%UCuts(2)%NumCuts ) call Error("Something went wrong while setting doub-cuts.")




!  set sing-cuts
   allocate(ThePrimAmp%UCuts(1)%TreeProcess(1:ThePrimAmp%UCuts(1)%NumCuts,1:1), stat=AllocStatus)
   if( AllocStatus .ne. 0 ) call Error("Memory allocation in ThePrimAmp%UCuts(1)%TreeProcess(ThePrimAmp%UCuts(1)%NumCuts,1).")

   NCut = 1
   do i5 = 1, NumExtParticles

!          skip cuts that are marked for discarding
           if( mod(ThePrimAmp%IntPart(i5)%PartType,1000) .eq. 0 ) cycle

!          set tree processes
!          vertex 1
           TheTree => ThePrimAmp%UCuts(1)%TreeProcess(NCut,1)
           NumVertPart = NumExtParticles
           TheTree%NumPart = NumVertPart+2
           allocate( TheTree%PartRef(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartRef 1-1")
           allocate( TheTree%PartType(1:NumVertPart+2), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%PartType 1-1")
!          set particle reference (wrt.prim.amp) and flavor
           TheTree%PartRef(1) = i5
           TheTree%PartType(1) = mod(ThePrimAmp%IntPart(i5)%PartType,1000)
           TheTree%PartRef(NumVertPart+2) = i5
           TheTree%PartType(NumVertPart+2) = ChargeConj(mod(ThePrimAmp%IntPart(i5)%PartType,1000) )
           do NPart=0,NumVertPart-1
               if( i5+NPart.le.NumExtParticles ) then
                  TheTree%PartRef(NPart+2) = i5+NPart
                  TheTree%PartType(NPart+2) = ExtParticle( ThePrimAmp%ExtLine(i5+NPart) )%PartType
               else
                  TheTree%PartRef(NPart+2) = i5+NPart-NumExtParticles
                  TheTree%PartType(NPart+2) = ExtParticle( ThePrimAmp%ExtLine(i5+NPart-NumExtParticles) )%PartType
               endif
           enddo

!          check for massless internal particles
           MasslessIntParticles = .false.
           if( ThePrimAmp%IntPart(i5)%Mass .le. 1d-10 ) then
               MasslessIntParticles = .true.
           endif

!          check for massless tadpole
           if( MasslessIntParticles ) then
               deallocate( ThePrimAmp%UCuts(1)%TreeProcess(NCut,1)%PartRef )
               deallocate( ThePrimAmp%UCuts(1)%TreeProcess(NCut,1)%PartType )
               ThePrimAmp%UCuts(1)%NumCuts = ThePrimAmp%UCuts(1)%NumCuts - 1
           else
!              set sing cut
               ThePrimAmp%UCuts(1)%CutProp(NCut,1) = i5
               NCut = NCut + 1
!            print *, NCut-1, ThePrimAmp%UCuts(1)%CutProp(NCut-1,1)
!            print *, 'tree 1:', ThePrimAmp%UCuts(1)%TreeProcess(NCut-1,1)%PartType(1:TheTree%NumPart)


           endif
   enddo
   if ( NCut-1 .ne. ThePrimAmp%UCuts(1)%NumCuts ) call Error("Something went wrong while setting sing-cuts.")

   do NPoint=1,5
      do NCut=1,ThePrimAmp%UCuts(NPoint)%NumCuts
          ThePrimAmp%UCuts(NPoint)%skip(NCut)=.false.
         do NTree=1,NPoint

            TheTree => ThePrimAmp%UCuts(NPoint)%TreeProcess(NCut,NTree)
!           set number of quarks and gluons
            TheTree%NumQua = 0
            TheTree%NumSca = 0
            TheTree%NumV = 0
            counterQ = 0
            do NPart=1,TheTree%NumPart
                  if( IsAQuark(TheTree%PartType(NPart)) ) then
                     TheTree%NumQua = TheTree%NumQua + 1
                     counterQ = counterQ + 1
                     QuarkPos(counterQ) = NPart
                  elseif( IsAScalar(TheTree%PartType(NPart)) ) then
                     TheTree%NumSca = TheTree%NumSca + 1
                     counterQ = counterQ + 1!     treat the scalar like a quark here because
                     QuarkPos(counterQ) = NPart!  this is only to determine NumGlu 
                  endif
            enddo

            if( IsAQuark(TheTree%PartType(1))  .or. IsAScalar(TheTree%PartType(1)) ) then
               allocate( TheTree%NumGlu(0:TheTree%NumQua+TheTree%NumSca), stat=AllocStatus )
               TheTree%NumGlu(0:TheTree%NumQua+TheTree%NumSca) = 0
            elseif( TheTree%PartType(1).eq.Glu_ ) then
               allocate( TheTree%NumGlu(0:TheTree%NumQua+TheTree%NumSca+1), stat=AllocStatus )
               TheTree%NumGlu(0:TheTree%NumQua+TheTree%NumSca+1) = 0
            else
               call Error("TheTree%NumGlu")
            endif
            if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%NumGlu")
            do NPart=1,TheTree%NumPart
               if( TheTree%PartType(NPart) .eq. Glu_ ) then
                  TheTree%NumGlu(0) = TheTree%NumGlu(0) + 1 
! If there is an EW boson (just Z for the moment), will overcount gluons, so remove these particles
                  ! This is a clumsy way to do things, but here goes...

               endif
            enddo

!           set number of gluons between quark or scalar lines
            if( IsAQuark(TheTree%PartType(1)) .or. IsAScalar(TheTree%PartType(1)) ) then
            if( TheTree%NumQua+TheTree%NumSca .eq. 2 ) then
                  TheTree%NumGlu(1) = QuarkPos(2) - QuarkPos(1) - 1
                  TheTree%NumGlu(2) = TheTree%NumPart - QuarkPos(2)
            endif
            if( TheTree%NumQua+TheTree%NumSca .eq. 4 ) then
                  TheTree%NumGlu(1) = QuarkPos(2) - QuarkPos(1) - 1
                  TheTree%NumGlu(2) = QuarkPos(3) - QuarkPos(2) - 1
                  TheTree%NumGlu(3) = QuarkPos(4) - QuarkPos(3) - 1
                  TheTree%NumGlu(4) = TheTree%NumPart - QuarkPos(4)
            endif
            if( TheTree%NumQua+TheTree%NumSca .eq. 6 ) then
                  TheTree%NumGlu(1) = QuarkPos(2) - QuarkPos(1) - 1
                  TheTree%NumGlu(2) = QuarkPos(3) - QuarkPos(2) - 1
                  TheTree%NumGlu(3) = QuarkPos(4) - QuarkPos(3) - 1
                  TheTree%NumGlu(4) = QuarkPos(5) - QuarkPos(4) - 1
                  TheTree%NumGlu(5) = QuarkPos(6) - QuarkPos(5) - 1
                  TheTree%NumGlu(6) = TheTree%NumPart - QuarkPos(6)
            endif
            elseif( TheTree%PartType(1).eq.Glu_ ) then
            if( TheTree%NumQua+TheTree%NumSca .eq. 2 ) then
                  TheTree%NumGlu(1) = QuarkPos(1) - 2
                  TheTree%NumGlu(2) = QuarkPos(2) - QuarkPos(1) - 1
                  TheTree%NumGlu(3) = TheTree%NumPart - QuarkPos(2)
            endif
            if( TheTree%NumQua+TheTree%NumSca .eq. 4 ) then
                  TheTree%NumGlu(1) = QuarkPos(1) - 2
                  TheTree%NumGlu(2) = QuarkPos(2) - QuarkPos(1) - 1
                  TheTree%NumGlu(3) = QuarkPos(3) - QuarkPos(2) - 1
                  TheTree%NumGlu(4) = QuarkPos(4) - QuarkPos(3) - 1
                  TheTree%NumGlu(5) = TheTree%NumPart - QuarkPos(4)
            endif
            if( TheTree%NumQua+TheTree%NumSca .eq. 6 ) then
                  TheTree%NumGlu(1) = QuarkPos(1) - 2
                  TheTree%NumGlu(2) = QuarkPos(2) - QuarkPos(1) - 1
                  TheTree%NumGlu(3) = QuarkPos(3) - QuarkPos(2) - 1
                  TheTree%NumGlu(4) = QuarkPos(4) - QuarkPos(3) - 1
                  TheTree%NumGlu(5) = QuarkPos(5) - QuarkPos(4) - 1
                  TheTree%NumGlu(6) = QuarkPos(6) - QuarkPos(5) - 1
                  TheTree%NumGlu(7) = TheTree%NumPart - QuarkPos(6)
            endif
            endif

            do NPart=1,TheTree%NumPart
               if( TheTree%PartType(NPart).eq.Z0_ .or. TheTree%PartType(NPart).eq.Pho_  .or. TheTree%PartType(NPart) .eq. Hig_ ) then
                  TheTree%NumV = TheTree%NumV + 1
                  LastQuark=0
                  do j=1, NPart-1   
                     if (IsAQuark(TheTree%PartType(j))) then
                        LastQuark=LastQuark+1
                     endif
                  enddo
                  TheTree%BosonVertex = LastQuark! this variable specifies to which quark flavor the vector boson couples
!                  TheTree%NumGlu(0) = TheTree%NumGlu(0) - 1
                  
                  if( IsAQuark(TheTree%PartType(1)) .or. IsAScalar(TheTree%PartType(1)) ) then
                     if ( TheTree%NumQua+TheTree%NumSca .eq. 2 ) then
                        if ( QuarkPos(1) .lt. NPart .and. QuarkPos(2) .gt. NPart) then
                           TheTree%NumGlu(1)=TheTree%NumGlu(1)-1
                        else
                           TheTree%NumGlu(2)=TheTree%NumGlu(2)-1
                        endif
                     elseif( TheTree%NumQua+TheTree%NumSca .eq. 4 ) then
                        if ( QuarkPos(1) .lt. NPart .and. QuarkPos(2) .gt. NPart) then
                           TheTree%NumGlu(1)=TheTree%NumGlu(1)-1
                        elseif ( QuarkPos(2) .lt. NPart .and. QuarkPos(3) .gt. NPart) then
                           TheTree%NumGlu(2)=TheTree%NumGlu(2)-1
                        elseif ( QuarkPos(3) .lt. NPart .and. QuarkPos(4) .gt. NPart) then
                           TheTree%NumGlu(3)=TheTree%NumGlu(3)-1
                        else
                           TheTree%NumGlu(4)=TheTree%NumGlu(4)-1
                        endif
                        
                     elseif( TheTree%NumQua+TheTree%NumSca .eq. 6 ) then
                        if ( QuarkPos(1) .lt. NPart .and. QuarkPos(2) .gt. NPart) then
                           TheTree%NumGlu(1)=TheTree%NumGlu(1)-1
                        elseif ( QuarkPos(2) .lt. NPart .and. QuarkPos(3) .gt. NPart) then
                           TheTree%NumGlu(2)=TheTree%NumGlu(2)-1
                        elseif ( QuarkPos(3) .lt. NPart .and. QuarkPos(4) .gt. NPart) then
                           TheTree%NumGlu(3)=TheTree%NumGlu(3)-1
                        elseif ( QuarkPos(4) .lt. NPart .and. QuarkPos(5) .gt. NPart) then
                           TheTree%NumGlu(4)=TheTree%NumGlu(4)-1
                        elseif ( QuarkPos(3) .lt. NPart .and. QuarkPos(6) .gt. NPart) then
                           TheTree%NumGlu(5)=TheTree%NumGlu(5)-1
                        else
                           TheTree%NumGlu(6)=TheTree%NumGlu(6)-1
                        endif
                     else
                        call Error("Tree with EW boson and > 6 quarks not supported")
                     endif
                     
                  elseif( TheTree%PartType(1).eq.Glu_ ) then
                     if( TheTree%NumQua+TheTree%NumSca .eq. 2 ) then
                        if (NPart .gt. 1 .and. NPart .lt. QuarkPos(1)) then
                           TheTree%NumGlu(1)=TheTree%NumGlu(1)-1
                        elseif (QuarkPos(1) .lt. NPart .and. QuarkPos(2) .gt. NPart) then
                           TheTree%NumGlu(2)=TheTree%NumGlu(2)-1
                        else
                           TheTree%NumGlu(3)=TheTree%NumGlu(3)-1
                        endif
                     elseif( TheTree%NumQua+TheTree%NumSca .eq. 4 ) then
                        if (NPart .gt. 1 .and. NPart .lt. QuarkPos(1)) then
                           TheTree%NumGlu(1)=TheTree%NumGlu(1)-1
                        elseif (QuarkPos(1) .lt. NPart .and. QuarkPos(2) .gt. NPart) then
                           TheTree%NumGlu(2)=TheTree%NumGlu(2)-1
                        elseif (QuarkPos(2) .lt. NPart .and. QuarkPos(3) .gt. NPart) then
                           TheTree%NumGlu(3)=TheTree%NumGlu(3)-1
                        elseif (QuarkPos(3) .lt. NPart .and. QuarkPos(4) .gt. NPart) then
                           TheTree%NumGlu(4)=TheTree%NumGlu(4)-1
                        else
                           TheTree%NumGlu(5)=TheTree%NumGlu(5)-1
                        endif
                     else
                        call Error("Tree with EW boson and initial gluon and > 4 quarks not supported")
                     endif
                  endif
               endif
            enddo


!          allocate memory for pointer to quarks
           allocate( TheTree%Quarks(1:TheTree%NumQua), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%Quarks")
!          allocate memory for pointer to gluons
           allocate( TheTree%Gluons(1:TheTree%NumGlu(0)), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%Gluons")
!          allocate memory for pointer to scalars
           allocate( TheTree%Scalars(1:TheTree%NumSca), stat=AllocStatus )
           if( AllocStatus .ne. 0 ) call Error("Memory allocation in TheTree%Scalars")

           counterQ = 0
           counterG = 0
           counterS = 0
           counterV = 0

           do NPart=1,TheTree%NumPart
               if( IsAQuark(TheTree%PartType(NPart)) ) then
                     counterQ = counterQ + 1
                     if( NPart.eq.1 .or. NPart.eq.TheTree%NumPart) then    ! first and last particles are in the loop
                        TheTree%Quarks(counterQ)%PartType => TheTree%PartType(NPart)
                        TheTree%Quarks(counterQ)%ExtRef => ThePrimAmp%IntPart( TheTree%PartRef(NPart) )%ExtRef
                        TheTree%Quarks(counterQ)%Mass => ThePrimAmp%IntPart( TheTree%PartRef(NPart) )%Mass
                        TheTree%Quarks(counterQ)%Mass2 => ThePrimAmp%IntPart( TheTree%PartRef(NPart) )%Mass2
                        TheTree%Quarks(counterQ)%Helicity => Null()
                        TheTree%Quarks(counterQ)%Mom => Null()
                        TheTree%Quarks(counterQ)%Pol => Null()
                     else
                        TheTree%Quarks(counterQ)%PartType => TheTree%PartType(NPart)
                        TheTree%Quarks(counterQ)%ExtRef => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%ExtRef
                        TheTree%Quarks(counterQ)%Mass => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%Mass
                        TheTree%Quarks(counterQ)%Mass2 => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%Mass2
                        TheTree%Quarks(counterQ)%Helicity => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%Helicity
                        TheTree%Quarks(counterQ)%Mom => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%Mom
                        TheTree%Quarks(counterQ)%Pol => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%Pol
                     endif
               endif
               if( TheTree%PartType(NPart) .eq. Glu_ ) then
                     counterG = counterG + 1
                     if( NPart.eq.1 .or. NPart.eq.TheTree%NumPart) then    ! first and last particles are in the loop
                        TheTree%Gluons(counterG)%PartType => TheTree%PartType(NPart)
                        TheTree%Gluons(counterG)%ExtRef => ThePrimAmp%IntPart( TheTree%PartRef(NPart) )%ExtRef
                        TheTree%Gluons(counterG)%Mass => ThePrimAmp%IntPart( TheTree%PartRef(NPart) )%Mass
                        TheTree%Gluons(counterG)%Mass2 => ThePrimAmp%IntPart( TheTree%PartRef(NPart) )%Mass2
                        TheTree%Gluons(counterG)%Helicity => Null()
                        TheTree%Gluons(counterG)%Mom => Null()
                        TheTree%Gluons(counterG)%Pol => Null()
                     else
                        TheTree%Gluons(counterG)%PartType => TheTree%PartType(NPart)
                        TheTree%Gluons(counterG)%ExtRef => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%ExtRef
                        TheTree%Gluons(counterG)%Mass => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%Mass
                        TheTree%Gluons(counterG)%Mass2 => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%Mass2
                        TheTree%Gluons(counterG)%Helicity => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%Helicity
                        TheTree%Gluons(counterG)%Mom => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%Mom
                        TheTree%Gluons(counterG)%Pol => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%Pol
                     endif
               endif
               if( IsAScalar(TheTree%PartType(NPart)) ) then
                     counterS = counterS + 1
                     if( NPart.eq.1 .or. NPart.eq.TheTree%NumPart) then    ! first and last particles are in the loop
                        TheTree%Scalars(counterS)%PartType => TheTree%PartType(NPart)
                        TheTree%Scalars(counterS)%ExtRef => ThePrimAmp%IntPart( TheTree%PartRef(NPart) )%ExtRef
                        TheTree%Scalars(counterS)%Mass => ThePrimAmp%IntPart( TheTree%PartRef(NPart) )%Mass
                        TheTree%Scalars(counterS)%Mass2 => ThePrimAmp%IntPart( TheTree%PartRef(NPart) )%Mass2
                        TheTree%Scalars(counterS)%Helicity => Null()
                        TheTree%Scalars(counterS)%Mom => Null()
                        TheTree%Scalars(counterS)%Pol => Null()
                     else
                        TheTree%Scalars(counterS)%PartType => TheTree%PartType(NPart)
                        TheTree%Scalars(counterS)%ExtRef => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%ExtRef
                        TheTree%Scalars(counterS)%Mass => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%Mass
                        TheTree%Scalars(counterS)%Mass2 => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%Mass2
                        TheTree%Scalars(counterS)%Helicity => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%Helicity
                        TheTree%Scalars(counterS)%Mom => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%Mom
                        TheTree%Scalars(counterS)%Pol => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%Pol
                     endif
                  endif
                  if( IsABoson(TheTree%PartType(NPart)) ) then
                     counterV = counterV + 1
                     if( counterV.ge.2 ) call Error("only one vector boson allowed",counterV)
                     if( NPart.eq.1 .or. NPart.eq.TheTree%NumPart) then
                        call Error("EW bosons not allowed in the loop!")
                     else
                        TheTree%Boson%PartType => TheTree%PartType(NPart)
                        TheTree%Boson%ExtRef => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%ExtRef
                        TheTree%Boson%Mass => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%Mass
                        TheTree%Boson%Mass2 => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%Mass2
                        TheTree%Boson%Helicity => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%Helicity
                        TheTree%Boson%Mom => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%Mom
                        TheTree%Boson%Pol => ExtParticle( ThePrimAmp%ExtLine(TheTree%PartRef(NPart)) )%Pol
                  endif
               endif
           enddo

         enddo
      enddo
   enddo



END SUBROUTINE





SUBROUTINE MatchUCuts(PrimAmp,Cut,HiCut,CutNum)
use ModMisc
implicit none
type(PrimitiveAmplitude),target :: PrimAmp
integer :: Cut,CutNum,HiCut,NumMatch,MatchHiCuts(1:20),FirstHiProp(1:20),MissHiProp(1:20,1:4)
integer :: Prop(1:5),HiProp(1:5),INTER(1:5),COMPL(1:5),FirstInterPos
integer :: i,numcheck,AllocStatus
type(UCutMatch),pointer :: TheMatch

NumMatch=0
do i=1,PrimAmp%UCuts(HiCut)%NumCuts
    Prop(1:Cut) = PrimAmp%UCuts(Cut)%CutProp(CutNum,1:Cut)
    HiProp(1:HiCut) = PrimAmp%UCuts(HiCut)%CutProp(i,1:HiCut)
    numcheck= MatchSets(HiProp(1:HiCut),Prop(1:Cut),INTER,COMPL,FirstInterPos)
    if( numcheck.eq.Cut ) then
        NumMatch=NumMatch+1
        MatchHiCuts(NumMatch)=i
        FirstHiProp(NumMatch)=FirstInterPos
        MissHiProp(NumMatch,1:HiCut-Cut)=COMPL(1:HiCut-Cut)
    endif
enddo

  TheMatch => PrimAmp%UCuts(Cut)%Match(CutNum)


  allocate(TheMatch%Subt(HiCut)%NumMatch(0:PrimAmp%NumSisters), stat=AllocStatus )
  if( AllocStatus .ne. 0 ) call Error("Memory allocation in MatchUCuts 1")


  TheMatch%Subt(HiCut)%NumMatch = NumMatch

  allocate(TheMatch%Subt(HiCut)%MatchHiCuts(0:PrimAmp%NumSisters,1:NumMatch), stat=AllocStatus )
  if( AllocStatus .ne. 0 ) call Error("Memory allocation in MatchUCuts 1")
  TheMatch%Subt(HiCut)%MatchHiCuts(0,1:NumMatch) = MatchHiCuts(1:NumMatch)

  allocate(TheMatch%Subt(HiCut)%FirstHiProp(0:PrimAmp%NumSisters,1:NumMatch), stat=AllocStatus )
  if( AllocStatus .ne. 0 ) call Error("Memory allocation in MatchUCuts 2")
  TheMatch%Subt(HiCut)%FirstHiProp(0,1:NumMatch) = FirstHiProp(1:NumMatch)

  allocate(TheMatch%Subt(HiCut)%MissHiProp(0:PrimAmp%NumSisters,1:NumMatch,1:HiCut-Cut), stat=AllocStatus )
  if( AllocStatus .ne. 0 ) call Error("Memory allocation in MatchUCuts 3")
  TheMatch%Subt(HiCut)%MissHiProp(0,1:NumMatch,1:HiCut-Cut) = MissHiProp(1:NumMatch,1:HiCut-Cut)

RETURN
END SUBROUTINE





SUBROUTINE MatchUCuts_new(PrimAmp,Cut,HiCut,CutNum)
use ModMisc
use modParameters
implicit none
type(PrimitiveAmplitude),target :: PrimAmp
type(PrimitiveAmplitude), pointer :: HiPrimAmp
integer :: Cut,CutNum,HiCut,NumMatch,MatchHiCuts(1:20),FirstHiProp(1:20),MissHiProp(1:20,1:4)
integer :: Prop(1:5),HiProp(1:5),INTER(1:5),COMPL(1:5),FirstInterPos
integer :: i,j,k,numcheck,AllocStatus,NewTree,OldTree,Nequivtrees,NCut,ZINOLDTREE,ZINNEWTREE
type(UCutMatch),pointer :: TheMatch
logical :: RejectWrongFlavor,AllTreesEquiv,are_equiv


  TheMatch => PrimAmp%UCuts(Cut)%Match(CutNum)

                                                           
  allocate(TheMatch%Subt(HiCut)%NumMatch(0:PrimAmp%NumSisters), stat=AllocStatus )
  if( AllocStatus .ne. 0 ) call Error("Memory allocation in MatchUCuts 1")
  allocate(TheMatch%Subt(HiCut)%MatchHiCuts(0:PrimAmp%NumSisters,1:50), stat=AllocStatus ) ! 1:50 is the maximum number of matches for a given primitive
  if( AllocStatus .ne. 0 ) call Error("Memory allocation in MatchUCuts 1")
  allocate(TheMatch%Subt(HiCut)%FirstHiProp(0:PrimAmp%NumSisters,1:50), stat=AllocStatus )
  if( AllocStatus .ne. 0 ) call Error("Memory allocation in MatchUCuts 2")
  allocate(TheMatch%Subt(HiCut)%MissHiProp(0:PrimAmp%NumSisters,1:50,1:5), stat=AllocStatus )   !   1:5 is the maximum number of missing propagators
  if( AllocStatus .ne. 0 ) call Error("Memory allocation in MatchUCuts 3")


do k=0,PrimAmp%NumSisters

  NumMatch=0

  if( k.eq.0 ) then
    HiPrimAmp => PrimAmp
  else
    HiPrimAmp => PrimAmps( PrimAmp%Sisters(k) )
  endif

  do i=1,HiPrimAmp%UCuts(HiCut)%NumCuts
      Prop(1:Cut) = PrimAmp%UCuts(Cut)%CutProp(CutNum,1:Cut)
      HiProp(1:HiCut) = HiPrimAmp%UCuts(HiCut)%CutProp(i,1:HiCut)
      numcheck= MatchSets(HiProp(1:HiCut),Prop(1:Cut),INTER,COMPL,FirstInterPos)

      RejectWrongFlavor=.false.
      do j=1,Cut
        if( PrimAmp%IntPart(INTER(j))%PartType .ne. HiPrimAmp%IntPart(INTER(j))%PartType ) then
            RejectWrongFlavor = .true.
            exit
        endif
      enddo

      if( numcheck.eq.Cut .and. .not.RejectWrongFlavor .and. .not.HiPrimAmp%UCuts(HiCut)%skip(i) ) then
          NumMatch=NumMatch+1
          MatchHiCuts(NumMatch)=i
          FirstHiProp(NumMatch)=FirstInterPos
          MissHiProp(NumMatch,1:HiCut-Cut)=COMPL(1:HiCut-Cut)
      endif
  enddo


  TheMatch%Subt(HiCut)%NumMatch(k) = NumMatch
  TheMatch%Subt(HiCut)%MatchHiCuts(k,1:NumMatch) = MatchHiCuts(1:NumMatch)
  TheMatch%Subt(HiCut)%FirstHiProp(k,1:NumMatch) = FirstHiProp(1:NumMatch)
  TheMatch%Subt(HiCut)%MissHiProp(k,1:NumMatch,1:HiCut-Cut) = MissHiProp(1:NumMatch,1:HiCut-Cut)



  








! M: UNDER CONSTRUCTION
!  if(  k.gt.0 .and. PrimAmp%AmpType.eq.2 .and. HiPrimAmp%AmpType.eq.2 ) then!  MARKUS: additional subtraction for closed fermion loops when sisters are present
!  
!print *, "MARKUS: CAREFUL! this code for subtractions of closed fermion loops is unfinished ";pause
!
!      do Ncut=1,PrimAmp%UCuts(Cut)%NumCuts
!      do i=1,HiPrimAmp%UCuts(HiCut)%NumCuts!   code in this do loop is very similar to the second part in SUBROUTINE REMOVE_DUPLICATE_CUTS
!                                           !   correspondance: PrimAmp~NewPrimAmp,  HiPrimAmp~OldPrimAmp
!
!
!
!
!                     ! now, loop over all trees in HiPrimAmp and PrimAmp
!                     AllTreesEquiv=.false.
!                     Nequivtrees = 0
!                     do NewTree=1,Cut
!                     do OldTree=1,HiCut
!                              call ARE_TREES_EQUIV(PrimAmp%UCuts(Cut)%TreeProcess(Ncut,NewTree),HiPrimAmp%UCuts(HiCut)%TreeProcess(i,OldTree2),are_equiv)
!                              if( are_equiv ) then! after this was true once, no other trees should be equal in this OldTree loop
!                                    Nequivtrees = Nequivtrees + 1
!                                    ! TODO: determine here FirstHiProp
!                              else
!                                    ! TODO: determine here MissHiProp(:)
!                              endif
!                              if( any( HiPrimAmp%UCuts(HiCut)%TreeProcess(i,OldTree)%PartType(:).eq.Z0_ )  ) ZinOldTree = OldTree! save the tree's with the Z0 boson
!                              if( any( PrimAmp%UCuts(Cut)%TreeProcess(NCut,NewTree)%PartType(:)   .eq.Z0_ )  ) ZinNewTree = NewTree! save the tree's with the Z0 boson
!                      enddo
!                      enddo
!                      if (Nequivtrees.eq.Cut) then
!                         AllTreesEquiv=.true.
!                      else
!                         AllTreesEquiv=.false.
!                      endif
!                      ! check if the tree with the Z0 boson is the one with external tops
!                      if( AllTreesEquiv .and. any( HiPrimAmp%UCuts(HiCut)%TreeProcess(i,ZinOldTree)%PartType(:).eq.Top_ ) &
!                                        .and. any( HiPrimAmp%UCuts(HiCut)%TreeProcess(i,ZinOldTree)%PartType(:).eq.ATop_) &
!                                        .and. any( PrimAmp%UCuts(Cut)%TreeProcess(NCut,ZinNewTree)%PartType(:).eq.Top_ ) &
!                                        .and. any( PrimAmp%UCuts(Cut)%TreeProcess(NCut,ZinNewTree)%PartType(:).eq.ATop_) ) then
!                          AllTreesEquiv=.true.
!                      else
!                          AllTreesEquiv=.false.
!                      endif
!
!                      if( AllTreesEquiv ) then
!
!                            ! TODO:  
!                                  NumMatch = TheMatch%Subt(HiCut)%NumMatch(k) + 1
!                                  MatchHiCuts(NumMatch) = i
!                                  FirstHiProp(NumMatch) =  99999999 ! to be determined above
!                                  MissHiProp(NumMatch,1:HiCut-Cut) = 999999! to be determined above
!
!
!                                  TheMatch%Subt(HiCut)%NumMatch(k) = TheMatch%Subt(HiCut)%NumMatch(k) + 1
!                                  TheMatch%Subt(HiCut)%MatchHiCuts(k,NumMatch) = MatchHiCuts(NumMatch)
!                                  TheMatch%Subt(HiCut)%FirstHiProp(k,NumMatch) = FirstHiProp(NumMatch)
!                                  TheMatch%Subt(HiCut)%MissHiProp(k,NumMatch,1:HiCut-Cut) = MissHiProp(NumMatch,1:HiCut-Cut)
!                      endif
!
!      enddo
!      enddo
!

!  endif


  






enddo

RETURN
END SUBROUTINE MatchUCuts_new





SUBROUTINE InfoPrimAmps(Filename)
use ModMisc
implicit none
type(PrimitiveAmplitude),pointer :: ThePrimAmp
integer :: NPrimAmp,NCut,NPart,k
character :: Filename*(*)


   open(unit=14,file=Filename,form='formatted',access= 'sequential',status='replace')


   write(14,"(A31,I3)") "Number of primitive amplitudes:",NumPrimAmps
   write(14,*) ""

   do NPrimAmp=1,NumBornAmps
      write(14,"(A31,10I3)") "LO amplitude: ",BornAmps(NPrimAmp)%TreeProc%PartType(1:NumExtParticles)
      write(14,"(A32,A100)") " ", WritePartType( BornAmps(NPrimAmp)%TreeProc%PartType(1:NumExtParticles) )
      write(14,*) ""
   enddo

   do NPrimAmp=1,NumPrimAmps
      ThePrimAmp => PrimAmps(NPrimAmp)
      write(14,"(A)") "----------------------------------------------------------------------------"
      write(14,"(A31,I3)") "Primitive amplitude: ",NPrimAmp
      if(ThePrimAmp%AmpType .eq.1) then
         write(14,"(A31,I3,A30)") "Amplitude type: ",ThePrimAmp%AmpType," (class (a) diagram)"
      elseif(ThePrimAmp%AmpType .eq.2) then
         write(14,"(A31,I3,A30)") "Amplitude type: ",ThePrimAmp%AmpType," (fermion loop diagram)"
      elseif(ThePrimAmp%AmpType .eq.3) then
         write(14,"(A31,I3,A30)") "Amplitude type: ",ThePrimAmp%AmpType," (class (b) diagram)"
      elseif(ThePrimAmp%AmpType .eq.4) then
         write(14,"(A31,I3,A30)") "Amplitude type: ",ThePrimAmp%AmpType," (class (c) diagram)"
      else
         write(14,"(A31,I3)") "Amplitude type: ",ThePrimAmp%AmpType
      endif

      write(14,"(A31,I3)") "N-Point: ",ThePrimAmp%NPoint
      write(14,"(A31,10I3)") "External ordering: ",ThePrimAmp%ExtLine(1:NumExtParticles)
      write(14,"(A32,A100)") " ", WritePartType( ExtParticle(ThePrimAmp%ExtLine(1:NumExtParticles))%PartType )
      write(14,"(A31,10I3)") "Internal ordering: ",ThePrimAmp%IntPart(1:NumExtParticles)%PartType
      write(14,"(A32,A100)") " ", WritePartType( ThePrimAmp%IntPart(1:NumExtParticles)%PartType )
      if( ThePrimAmp%NumSisters.ne.0 ) then
	  write(14,"(A31,10I3)") "Sister primitives: ",ThePrimAmp%Sisters(1:ThePrimAmp%NumSisters)
      else
	  write(14,"(A31,10I3)") "Sister primitives: ",0
      endif
      write(14,*) ""
      write(14,"(A)") "--------------------------------------"

      write(14,"(A31,I3)") "Number of pent-cuts: ",ThePrimAmp%UCuts(5)%NumCuts
      do NCut=1,ThePrimAmp%UCuts(5)%NumCuts
       write(14,"(A31,I3,A1,5I3)") "cut (pointer)",NCut,":",ThePrimAmp%UCuts(5)%CutProp(NCut,1:5)

       if( ThePrimAmp%UCuts(5)%Skip(NCut) ) then
          write(14,"(A31)") "skipped"
       else
         NPart = ThePrimAmp%UCuts(5)%TreeProcess(NCut,1)%NumPart
         write(14,"(A40,10I3)") "Tree 1:",ThePrimAmp%UCuts(5)%TreeProcess(NCut,1)%PartRef(1:NPart)
         write(14,"(A41,A100)") "       ",WritePartType( ThePrimAmp%UCuts(5)%TreeProcess(NCut,1)%PartType(1:NPart) )
         NPart = ThePrimAmp%UCuts(5)%TreeProcess(NCut,2)%NumPart
         write(14,"(A40,10I3)") "Tree 2:",ThePrimAmp%UCuts(5)%TreeProcess(NCut,2)%PartRef(1:NPart)
         write(14,"(A41,A100)") "       ",WritePartType( ThePrimAmp%UCuts(5)%TreeProcess(NCut,2)%PartType(1:NPart) )
         NPart = ThePrimAmp%UCuts(5)%TreeProcess(NCut,3)%NumPart
         write(14,"(A40,10I3)") "Tree 3:",ThePrimAmp%UCuts(5)%TreeProcess(NCut,3)%PartRef(1:NPart)
         write(14,"(A41,A100)") "       ",WritePartType( ThePrimAmp%UCuts(5)%TreeProcess(NCut,3)%PartType(1:NPart) )
         NPart = ThePrimAmp%UCuts(5)%TreeProcess(NCut,4)%NumPart
         write(14,"(A40,10I3)") "Tree 4:",ThePrimAmp%UCuts(5)%TreeProcess(NCut,4)%PartRef(1:NPart)
         write(14,"(A41,A100)") "       ",WritePartType( ThePrimAmp%UCuts(5)%TreeProcess(NCut,4)%PartType(1:NPart) )
         NPart = ThePrimAmp%UCuts(5)%TreeProcess(NCut,5)%NumPart
         write(14,"(A40,10I3)") "Tree 5:",ThePrimAmp%UCuts(5)%TreeProcess(NCut,5)%PartRef(1:NPart)
         write(14,"(A41,A100)") "       ",WritePartType( ThePrimAmp%UCuts(5)%TreeProcess(NCut,5)%PartType(1:NPart) )
       endif
      enddo

      write(14,"(A31,I3)") "Number of quad-cuts: ",ThePrimAmp%UCuts(4)%NumCuts
      do NCut=1,ThePrimAmp%UCuts(4)%NumCuts
         write(14,"(A31,I3,A1,4I3)") "cut (pointer)",NCut,":",ThePrimAmp%UCuts(4)%CutProp(NCut,1:4)
       if( ThePrimAmp%UCuts(4)%Skip(NCut) ) then
          write(14,"(A31)") "skipped"
       else
         do k=0,ThePrimAmp%NumSisters
            if( k.eq.0 ) write(14,"(A52)") "Subtraction from Primitive amplitude itself"
            if( k.gt.0 ) write(14,"(A43,I3)") "Subtraction from sister Primitive ",ThePrimAmp%Sisters(k)
            write(14,"(A40,10I3)") "Number of subtracted penta-cuts",ThePrimAmp%UCuts(4)%Match(NCut)%Subt(5)%NumMatch(k)
            write(14,"(A40,10I3)") "Label of subtracted penta-cuts ",ThePrimAmp%UCuts(4)%Match(NCut)%Subt(5)%MatchHiCuts(k,1:ThePrimAmp%UCuts(4)%Match(NCut)%Subt(5)%NumMatch(k))
         enddo
         NPart = ThePrimAmp%UCuts(4)%TreeProcess(NCut,1)%NumPart
         write(14,"(A40,10I3)") "Tree 1:",ThePrimAmp%UCuts(4)%TreeProcess(NCut,1)%PartRef(1:NPart)
         write(14,"(A41,A100)") "       ",WritePartType( ThePrimAmp%UCuts(4)%TreeProcess(NCut,1)%PartType(1:NPart) )
         NPart = ThePrimAmp%UCuts(4)%TreeProcess(NCut,2)%NumPart
         write(14,"(A40,10I3)") "Tree 2:",ThePrimAmp%UCuts(4)%TreeProcess(NCut,2)%PartRef(1:NPart)
         write(14,"(A41,A100)") "       ",WritePartType( ThePrimAmp%UCuts(4)%TreeProcess(NCut,2)%PartType(1:NPart) )
         NPart = ThePrimAmp%UCuts(4)%TreeProcess(NCut,3)%NumPart
         write(14,"(A40,10I3)") "Tree 3:",ThePrimAmp%UCuts(4)%TreeProcess(NCut,3)%PartRef(1:NPart)
         write(14,"(A41,A100)") "       ",WritePartType( ThePrimAmp%UCuts(4)%TreeProcess(NCut,3)%PartType(1:NPart) )
         NPart = ThePrimAmp%UCuts(4)%TreeProcess(NCut,4)%NumPart
         write(14,"(A40,10I3)") "Tree 4:",ThePrimAmp%UCuts(4)%TreeProcess(NCut,4)%PartRef(1:NPart)
         write(14,"(A41,A100)") "       ",WritePartType( ThePrimAmp%UCuts(4)%TreeProcess(NCut,4)%PartType(1:NPart) )
       endif
      enddo

      write(14,"(A31,I3)") "Number of trip-cuts: ",ThePrimAmp%UCuts(3)%NumCuts
      do NCut=1,ThePrimAmp%UCuts(3)%NumCuts
         write(14,"(A31,I3,A1,4I3)") "cut (pointer)",NCut,":",ThePrimAmp%UCuts(3)%CutProp(NCut,1:3)
       if( ThePrimAmp%UCuts(3)%Skip(NCut) ) then
          write(14,"(A31)") "skipped"
       else
         do k=0,ThePrimAmp%NumSisters
            if( k.eq.0 ) write(14,"(A52)") "Subtraction from Primitive amplitude itself"
            if( k.gt.0 ) write(14,"(A43,I3)") "Subtraction from sister Primitive ",ThePrimAmp%Sisters(k)
!             write(14,"(A40,10I3)") "Number of subtracted penta-cuts",ThePrimAmp%UCuts(3)%Match(NCut)%Subt(5)%NumMatch(k)
            write(14,"(A40,10I3)") "Label of subtracted penta-cuts ",ThePrimAmp%UCuts(3)%Match(NCut)%Subt(5)%MatchHiCuts(k,1:ThePrimAmp%UCuts(3)%Match(NCut)%Subt(5)%NumMatch(k))
!             write(14,"(A40,10I3)") "Number of subtracted quad-cuts ",ThePrimAmp%UCuts(3)%Match(NCut)%Subt(4)%NumMatch(k)
            write(14,"(A40,10I3)") "Label of subtracted quad-cuts  ",ThePrimAmp%UCuts(3)%Match(NCut)%Subt(4)%MatchHiCuts(k,1:ThePrimAmp%UCuts(3)%Match(NCut)%Subt(4)%NumMatch(k))
         enddo
         NPart = ThePrimAmp%UCuts(3)%TreeProcess(NCut,1)%NumPart
         write(14,"(A40,10I3)") "Tree 1:",ThePrimAmp%UCuts(3)%TreeProcess(NCut,1)%PartRef(1:NPart)
         write(14,"(A41,A100)") "       ",WritePartType( ThePrimAmp%UCuts(3)%TreeProcess(NCut,1)%PartType(1:NPart) )
         NPart = ThePrimAmp%UCuts(3)%TreeProcess(NCut,2)%NumPart
         write(14,"(A40,10I3)") "Tree 2:",ThePrimAmp%UCuts(3)%TreeProcess(NCut,2)%PartRef(1:NPart)
         write(14,"(A41,A100)") "       ",WritePartType( ThePrimAmp%UCuts(3)%TreeProcess(NCut,2)%PartType(1:NPart) )
         NPart = ThePrimAmp%UCuts(3)%TreeProcess(NCut,3)%NumPart
         write(14,"(A40,10I3)") "Tree 3:",ThePrimAmp%UCuts(3)%TreeProcess(NCut,3)%PartRef(1:NPart)
         write(14,"(A41,A100)") "       ",WritePartType( ThePrimAmp%UCuts(3)%TreeProcess(NCut,3)%PartType(1:NPart) )
       endif
      enddo

      write(14,"(A31,I3)") "Number of doub-cuts: ",ThePrimAmp%UCuts(2)%NumCuts
      do NCut=1,ThePrimAmp%UCuts(2)%NumCuts
         write(14,"(A31,I3,A1,4I3)") "cut (pointer)",NCut,":",ThePrimAmp%UCuts(2)%CutProp(NCut,1:2)
       if( ThePrimAmp%UCuts(2)%Skip(NCut) ) then
          write(14,"(A31)") "skipped"
       else
         do k=0,ThePrimAmp%NumSisters
            if( k.eq.0 ) write(14,"(A52)") "Subtraction from Primitive amplitude itself"
            if( k.gt.0 ) write(14,"(A43,I3)") "Subtraction from sister Primitive ",ThePrimAmp%Sisters(k)
!             write(14,"(A40,10I3)") "Number of subtracted penta-cuts",ThePrimAmp%UCuts(2)%Match(NCut)%Subt(5)%NumMatch(k)
            write(14,"(A40,10I3)") "Label of subtracted penta-cuts ",ThePrimAmp%UCuts(2)%Match(NCut)%Subt(5)%MatchHiCuts(k,1:ThePrimAmp%UCuts(2)%Match(NCut)%Subt(5)%NumMatch(k))
!             write(14,"(A40,10I3)") "Number of subtracted quad-cuts ",ThePrimAmp%UCuts(2)%Match(NCut)%Subt(4)%NumMatch(k)
            write(14,"(A40,10I3)") "Label of subtracted quad-cuts  ",ThePrimAmp%UCuts(2)%Match(NCut)%Subt(4)%MatchHiCuts(k,1:ThePrimAmp%UCuts(2)%Match(NCut)%Subt(4)%NumMatch(k))
!             write(14,"(A40,10I3)") "Number of subtracted trip-cuts ",ThePrimAmp%UCuts(2)%Match(NCut)%Subt(3)%NumMatch(k)
            write(14,"(A40,10I3)") "Label of subtracted trip-cuts  ",ThePrimAmp%UCuts(2)%Match(NCut)%Subt(3)%MatchHiCuts(k,1:ThePrimAmp%UCuts(2)%Match(NCut)%Subt(3)%NumMatch(k))
         enddo
         NPart = ThePrimAmp%UCuts(2)%TreeProcess(NCut,1)%NumPart
         write(14,"(A40,10I3)") "Tree 1:",ThePrimAmp%UCuts(2)%TreeProcess(NCut,1)%PartRef(1:NPart)
         write(14,"(A41,A100)") "       ",WritePartType( ThePrimAmp%UCuts(2)%TreeProcess(NCut,1)%PartType(1:NPart) )
         NPart = ThePrimAmp%UCuts(2)%TreeProcess(NCut,2)%NumPart
         write(14,"(A40,10I3)") "Tree 2:",ThePrimAmp%UCuts(2)%TreeProcess(NCut,2)%PartRef(1:NPart)
         write(14,"(A41,A100)") "       ",WritePartType( ThePrimAmp%UCuts(2)%TreeProcess(NCut,2)%PartType(1:NPart) )
       endif
      enddo

      write(14,"(A31,I3)") "Number of sing-cuts: ",ThePrimAmp%UCuts(1)%NumCuts
      do NCut=1,ThePrimAmp%UCuts(1)%NumCuts
         write(14,"(A31,I3,A1,4I3)") "cut (pointer)",NCut,":",ThePrimAmp%UCuts(1)%CutProp(NCut,1:1)
       if( ThePrimAmp%UCuts(1)%Skip(NCut) ) then
          write(14,"(A31)") "skipped"
       else
         do k=0,ThePrimAmp%NumSisters
            if( k.eq.0 ) write(14,"(A52)") "Subtraction from Primitive amplitude itself"
            if( k.gt.0 ) write(14,"(A43,I3)") "Subtraction from sister Primitive ",ThePrimAmp%Sisters(k)
!             write(14,"(A40,10I3)") "Number of subtracted penta-cuts",ThePrimAmp%UCuts(1)%Match(NCut)%Subt(5)%NumMatch(k)
            write(14,"(A40,10I3)") "Label of subtracted penta-cuts ",ThePrimAmp%UCuts(1)%Match(NCut)%Subt(5)%MatchHiCuts(k,1:ThePrimAmp%UCuts(1)%Match(NCut)%Subt(5)%NumMatch(k))
!             write(14,"(A40,10I3)") "Number of subtracted quad-cuts ",ThePrimAmp%UCuts(1)%Match(NCut)%Subt(4)%NumMatch(k)
            write(14,"(A40,10I3)") "Label of subtracted quad-cuts  ",ThePrimAmp%UCuts(1)%Match(NCut)%Subt(4)%MatchHiCuts(k,1:ThePrimAmp%UCuts(1)%Match(NCut)%Subt(4)%NumMatch(k))
!             write(14,"(A40,10I3)") "Number of subtracted trip-cuts ",ThePrimAmp%UCuts(1)%Match(NCut)%Subt(3)%NumMatch(k)
            write(14,"(A40,10I3)") "Label of subtracted trip-cuts  ",ThePrimAmp%UCuts(1)%Match(NCut)%Subt(3)%MatchHiCuts(k,1:ThePrimAmp%UCuts(1)%Match(NCut)%Subt(3)%NumMatch(k))
!             write(14,"(A40,10I3)") "Number of subtracted bubl-cuts ",ThePrimAmp%UCuts(1)%Match(NCut)%Subt(2)%NumMatch(k)
            write(14,"(A40,10I3)") "Label of subtracted bubl-cuts  ",ThePrimAmp%UCuts(1)%Match(NCut)%Subt(2)%MatchHiCuts(k,1:ThePrimAmp%UCuts(1)%Match(NCut)%Subt(2)%NumMatch(k))
         enddo
         NPart = ThePrimAmp%UCuts(1)%TreeProcess(NCut,1)%NumPart
         write(14,"(A40,10I3)") "Tree 1:",ThePrimAmp%UCuts(1)%TreeProcess(NCut,1)%PartRef(1:NPart)
         write(14,"(A41,A100)") "       ",WritePartType( ThePrimAmp%UCuts(1)%TreeProcess(NCut,1)%PartType(1:NPart) )
       endif
      enddo
   enddo
   write(14,*) ""
   close(14)

END SUBROUTINE




SUBROUTINE FindSubtractions()
use modMisc
implicit none
integer :: nPrimAmp,NCut,AllocStatus
type(PrimitiveAmplitude), pointer ::  ThePrimAmp

  do nPrimAmp=1,NumPrimAmps
         ThePrimAmp => PrimAmps(NPrimAmp)

      ! set cut matchings
	allocate( ThePrimAmp%UCuts(4)%Match(1:ThePrimAmp%UCuts(4)%NumCuts)  , stat=AllocStatus )
	if( AllocStatus .ne. 0 ) call Error("Memory allocation for quad cut matching")

	allocate( ThePrimAmp%UCuts(3)%Match(1:ThePrimAmp%UCuts(3)%NumCuts)  , stat=AllocStatus )
	if( AllocStatus .ne. 0 ) call Error("Memory allocation for trip cut matching")

	allocate( ThePrimAmp%UCuts(2)%Match(1:ThePrimAmp%UCuts(2)%NumCuts)  , stat=AllocStatus )
	if( AllocStatus .ne. 0 ) call Error("Memory allocation for doub cut matching")

	allocate( ThePrimAmp%UCuts(1)%Match(1:ThePrimAmp%UCuts(1)%NumCuts)  , stat=AllocStatus )
	if( AllocStatus .ne. 0 ) call Error("Memory allocation for sing cut matching")

! 	do NCut=1,ThePrimAmp%UCuts(4)%NumCuts
! 	  call MatchUCuts(ThePrimAmp,4,5,NCut)
! 	enddo
! 
! 	do NCut=1,ThePrimAmp%UCuts(3)%NumCuts
! 	  call MatchUCuts(ThePrimAmp,3,5,NCut)
! 	  call MatchUCuts(ThePrimAmp,3,4,NCut)
! 	enddo
! 
! 	do NCut=1,ThePrimAmp%UCuts(2)%NumCuts
! 	  call MatchUCuts(ThePrimAmp,2,5,NCut)
! 	  call MatchUCuts(ThePrimAmp,2,4,NCut)
! 	  call MatchUCuts(ThePrimAmp,2,3,NCut)
! 	enddo
! 
! 	do NCut=1,ThePrimAmp%UCuts(1)%NumCuts
! 	  call MatchUCuts(ThePrimAmp,1,5,NCut)
! 	  call MatchUCuts(ThePrimAmp,1,4,NCut)
! 	  call MatchUCuts(ThePrimAmp,1,3,NCut)
! 	  call MatchUCuts(ThePrimAmp,1,2,NCut)
! 	enddo



	do NCut=1,ThePrimAmp%UCuts(4)%NumCuts
	  call MatchUCuts_new(ThePrimAmp,4,5,NCut)
	enddo

	do NCut=1,ThePrimAmp%UCuts(3)%NumCuts
	  call MatchUCuts_new(ThePrimAmp,3,5,NCut)
	  call MatchUCuts_new(ThePrimAmp,3,4,NCut)
	enddo

	do NCut=1,ThePrimAmp%UCuts(2)%NumCuts
	  call MatchUCuts_new(ThePrimAmp,2,5,NCut)
	  call MatchUCuts_new(ThePrimAmp,2,4,NCut)
	  call MatchUCuts_new(ThePrimAmp,2,3,NCut)
	enddo

	do NCut=1,ThePrimAmp%UCuts(1)%NumCuts
	  call MatchUCuts_new(ThePrimAmp,1,5,NCut)
	  call MatchUCuts_new(ThePrimAmp,1,4,NCut)
	  call MatchUCuts_new(ThePrimAmp,1,3,NCut)
	  call MatchUCuts_new(ThePrimAmp,1,2,NCut)
	enddo




  enddo

END SUBROUTINE












SUBROUTINE REMOVE_DUPLICATE_CUTS()
use ModMisc
use ModParameters
implicit none
    ! Routine to remove duplicate cuts from different parent diagrams
!      type(PrimitiveAmplitude)          :: P
      type(PrimitiveAmplitude),pointer :: NewPrimAmp, OldPrimAmp
      integer                          :: Npoint, NCut, NParent,j, NTree, Nequivtrees, NPrimAmp,OldNcut
      integer                          :: NewTree,OldTree,ZinNewTree,ZinOldTree
      logical                          :: are_equiv,AllTreesEquiv



      do NPrimAmp=2,NumPrimAmps! the way we compare is (2 vs. 1), (3 vs. 1,2), (4 vs. 1,2,3), ...
         NewPrimAmp => PrimAmps(NPrimAmp)
         do Npoint = 1,5                                                  ! Over 5,4,3,2,1 cuts
            do Ncut = 1, NewPrimAmp%UCuts(NPoint)%NumCuts      ! over the number of n-cuts
            j = 0
            do while ( ( NewPrimAmp%UCuts(Npoint)%skip(NCut) .eq. .false.) .and. (j+1 .lt. NPrimAmp))
  ! M: Shouldn't it be enough to loop over sisters only, instead of all other primitives? Would be saver because all existing PrimAmps have 0 sisters.
            
!            do j=1,NewPrimAmp%NumSisters
               
                  j = j+1
!                  OldPrimAmp => PrimAmps(NewPrimAmp%Sisters(j))
                  OldPrimAmp => PrimAmps(j)
                  if (NewPrimAmp%UCuts(NPoint)%skip(NCut)) cycle
                  OldNCut=0
!                  do OldNcut=1,OldPrimAmp%UCuts(Npoint)%NumCuts
                  do while ( (OldNCut .lt. OldPrimAmp%UCuts(Npoint)%NumCuts).and. (NewPrimAmp%UCuts(Npoint)%skip(NCut) .eq. .false.) )
                     OldNCut=OldNCut+1

                     if ( OldPrimAmp%AmpType .ne. NewPrimAmp%AmpType) cycle
                     if ( OldPrimAmp%UCuts(Npoint)%skip(OldNCut) .eq. .true.) cycle
                     if ( OldPrimAmp%UCuts(Npoint)%NumCuts .ne. NewPrimAmp%UCuts(Npoint)%NumCuts) cycle !  M: why is this condition required ?

                     Nequivtrees = 0
                  ! This should always be true, put in as a additional safety net
                     if (all(NewPrimAmp%UCuts(Npoint)%CutProp(NCut,:) .eq. OldPrimAmp%UCuts(Npoint)%CutProp(OldNCut,:))) then

                        do NTree = 1,Npoint
                           call ARE_TREES_EQUIV(NewPrimAmp%UCuts(Npoint)%TreeProcess(NCut,Ntree),OldPrimAmp%UCuts(Npoint)%TreeProcess(OldNCut,Ntree),are_equiv)
                           if (are_equiv) Nequivtrees = Nequivtrees+1
                        enddo
                     endif
                     if (Nequivtrees == Npoint) then                        ! all trees equivalent = duplicate cut!
                        NewPrimAmp%UCuts(Npoint)%skip(NCut) = .true.
                     else
                        NewPrimAmp%UCuts(Npoint)%skip(NCut) = .false.
                     endif
                   enddo
            enddo    ! j: OldPrimAmp => PrimAmps(j)
            enddo       ! Ncut
         enddo          ! NParent
      enddo             ! NPoint

    end SUBROUTINE REMOVE_DUPLICATE_CUTS

subroutine REMOVE_DUPLICATE_CUTS_BETTER()
use ModMisc
use ModParameters
implicit none
! Routine to remove duplicate cuts from different parent diagrams
!      type(PrimitiveAmplitude)          :: P
type(PrimitiveAmplitude),pointer :: NewPrimAmp, OldPrimAmp
integer                          :: Npoint, NCut, NParent,j, NTree, Nequivtrees, NPrimAmp,OldNcut,NumSisters,NewNCut
integer                          :: NewTree,OldTree,ZinNewTree,ZinOldTree
logical                          :: are_equiv,AllTreesEquiv

do NPrimAmp=1,NumPrimAmps! the way we compare is (2 vs. 1), (3 vs. 1,2), (4 vs. 1,2,3), ...
   OldPrimAmp => PrimAmps(NPrimAmp)
   NumSisters  = OldPrimAmp%NumSisters
   if (NumSisters .eq. 0) cycle
   do j=NPrimAmp+1,OldPrimAmp%Sisters(NumSisters)
      NewPrimAmp => PrimAmps(j)
      
! safety net
      if ( OldPrimAmp%AmpType .ne. NewPrimAmp%AmpType) cycle
      
      do NPoint = 1,5
         do NCut = 1, NewPrimAmp%UCuts(NPoint)%NumCuts
            
            OldNCut=0
            do while (OldNCut .lt. OldPrimAmp%UCuts(NPoint)%NumCuts .and. &
                 & (NewPrimAmp%UCuts(Npoint)%skip(NCut) .eq. .false.) )
!.and. &
!                 NewPrimAmp%UCuts(NPoint)%skip(NewNCut+1) .eq. .false.)
               OldNCut=OldNCut+1
               if ( OldPrimAmp%UCuts(Npoint)%skip(OldNCut) .eq. .true.) cycle
               if ( OldPrimAmp%UCuts(Npoint)%NumCuts .ne. NewPrimAmp%UCuts(Npoint)%NumCuts) cycle !  M: why is this condition required ?

               Nequivtrees = 0
               ! This should always be true, put in as a additional safety net
               if (all(NewPrimAmp%UCuts(Npoint)%CutProp(NCut,:) .eq. OldPrimAmp%UCuts(Npoint)%CutProp(OldNCut,:))) then  

                  do NTree = 1,Npoint
                     call ARE_TREES_EQUIV(NewPrimAmp%UCuts(Npoint)%TreeProcess(NCut,Ntree),OldPrimAmp%UCuts(Npoint)%TreeProcess(OldNCut,Ntree),are_equiv)
                     if (are_equiv) Nequivtrees = Nequivtrees+1
                  enddo
               endif

               if (Nequivtrees == Npoint) then                        ! all trees equivalent = duplicate cut!
                  NewPrimAmp%UCuts(Npoint)%skip(NCut) = .true.
               else
                  NewPrimAmp%UCuts(Npoint)%skip(NCut) = .false.
               endif
            enddo     ! NewNCut
         enddo        ! NCut
      enddo           ! NPoint
   enddo              ! j NewPrimAmp => PrimAmps(j)
enddo
end subroutine REMOVE_DUPLICATE_CUTS_BETTER


    SUBROUTINE REMOVE_CYCLIC_DUPLICATES()
     use ModMisc
     use ModParameters
     implicit none
    ! Routine to remove duplicate cuts from different parent diagrams
!      type(PrimitiveAmplitude)          :: P
      type(PrimitiveAmplitude),pointer :: NewPrimAmp, OldPrimAmp
      integer                          :: Npoint, NCut, NParent,j, NTree, Nequivtrees, NPrimAmp,OldNcut
      integer                          :: NewTree,OldTree,ZinNewTree,ZinOldTree
      logical                          :: are_equiv,AllTreesEquiv
 

! MARKUS: remove additional duplicates for AmpType=2
      do NPrimAmp=2,NumPrimAmps!  idea: select Primamp (called New) and compare it to all others (called Old). The way we compare is (2 vs. 1), (3 vs. 1,2), (4 vs. 1,2,3), ...
         NewPrimAmp => PrimAmps(NPrimAmp)
         if( NewPrimAmp%AmpType.ne.2 ) cycle
         
         do Npoint = 1,5
         do Ncut = 1,NewPrimAmp%UCuts(NPoint)%NumCuts
                ! to this point we have selected a cut for the NewPrimAmp
                
                ! now, loop over all OldPrimAmps  ! M: Shouldn't it be enough to loop over sisters only,instead of all other primitives? Would be saver because all existing PrimAmps have 0 sisters.
!                j = 0
!                do while ( ( NewPrimAmp%UCuts(Npoint)%skip(NCut) .eq. .false.) .and. (j+1 .lt. NPrimAmp))
!                   j = j+1
            do j=1,NewPrimAmp%NumSisters
!                   OldPrimAmp => PrimAmps(j)
               OldPrimAmp => PrimAmps(NewPrimAmp%Sisters(j))
               if (NewPrimAmp%Sisters(j) .ge. NPrimAmp) cycle
                   OldNCut=0

                   if ( OldPrimAmp%AmpType .ne. NewPrimAmp%AmpType) cycle

                   do while ( (OldNCut.lt.OldPrimAmp%UCuts(Npoint)%NumCuts) .and. (NewPrimAmp%UCuts(Npoint)%skip(NCut).eq..false.) )
                     OldNCut=OldNCut+1
                     ! to this point we have selected a cut for the OldPrimAmp and NewPrimAmp

                     if ( OldPrimAmp%UCuts(Npoint)%skip(OldNCut) .eq. .true.) cycle

! print *, "npoint",Npoint
! print *, "comparing primamp",NPrimAmp,j
! print *, "comparing ncut",Ncut,OldNCut

                     ! now, loop over all trees in OldPrimAmp and NewPrimAmp
                     AllTreesEquiv=.false.
                     Nequivtrees = 0
                     ZinOldTree=-1
                     ZinNewTree=-1
                     do NewTree=1,Npoint
                        do OldTree=1,Npoint
                           
                           call ARE_TREES_EQUIV(NewPrimAmp%UCuts(Npoint)%TreeProcess(NCut,NewTree),OldPrimAmp%UCuts(Npoint)%TreeProcess(OldNCut,OldTree),are_equiv)
                              if( are_equiv ) then! after this was true once, no other trees should be equal in this OldTree loop
                                    Nequivtrees = Nequivtrees + 1
                              endif
                              if( any( OldPrimAmp%UCuts(Npoint)%TreeProcess(OldNCut,OldTree)%PartType(:).eq.Z0_ ) .or.  any( OldPrimAmp%UCuts(Npoint)%TreeProcess(OldNCut,OldTree)%PartType(:).eq.Pho_ )  .or. any( OldPrimAmp%UCuts(Npoint)%TreeProcess(OldNCut,OldTree)%PartType(:).eq.Hig_ ) ) ZinOldTree = OldTree! save the tree's with the Z0 boson
                              if( any( NewPrimAmp%UCuts(Npoint)%TreeProcess(NCut,NewTree)%PartType(:)   .eq.Z0_) .or. any( NewPrimAmp%UCuts(Npoint)%TreeProcess(NCut,NewTree)%PartType(:)   .eq.Pho_ )  .or. any( NewPrimAmp%UCuts(Npoint)%TreeProcess(NCut,NewTree)%PartType(:)   .eq.Hig_ ) ) ZinNewTree = NewTree! save the tree's with the Z0 boson
                      enddo
                      enddo
                      if (ZinOldTree .eq. -1 .or. ZinNewTree .eq. -1) call Error("Cyclic duplicates found with no Z!")

                      if (Nequivtrees.eq.Npoint) then
                         AllTreesEquiv=.true.
                      else
                         AllTreesEquiv=.false.
                      endif
                      ! check if the tree with the Z0 boson is the one with external tops
                      if( AllTreesEquiv .and. any( OldPrimAmp%UCuts(Npoint)%TreeProcess(OldNCut,ZinOldTree)%PartType(:).eq.Top_ ) &
                                        .and. any( OldPrimAmp%UCuts(Npoint)%TreeProcess(OldNCut,ZinOldTree)%PartType(:).eq.ATop_) &
                                        .and. any( NewPrimAmp%UCuts(Npoint)%TreeProcess(NCut,ZinNewTree)%PartType(:).eq.Top_ ) &
                                        .and. any( NewPrimAmp%UCuts(Npoint)%TreeProcess(NCut,ZinNewTree)%PartType(:).eq.ATop_) ) then
                          AllTreesEquiv=.true.
!                          call inherit_subtr(NPrimAmp,j,NCut,OldNCut,NPoint)
                          call inherit_subtr(NPrimAmp,NewPrimAmp%Sisters(j),NCut,OldNCut,NPoint)
                      else
                          AllTreesEquiv=.false.
                      endif

                      if( AllTreesEquiv ) then
!                             print *, "checker: ",NPoint,Nequivtrees
!                             print *, "checker: New amp,cut",NPrimAmp,NewPrimAmp%UCuts(Npoint)%CutProp(NCut,:)
!                             print *, "checker: Old amp,cut",j,OldPrimAmp%UCuts(Npoint)%CutProp(OldNCut,:)
                            NewPrimAmp%UCuts(Npoint)%skip(NCut) = .true.
                      else
                            NewPrimAmp%UCuts(Npoint)%skip(NCut) = .false.
                      endif
                   enddo
                enddo

         enddo! Ncut
         enddo! Npoint
      enddo! NPrimAmp

    end SUBROUTINE REMOVE_CYCLIC_DUPLICATES





    SUBROUTINE inherit_subtr(NewPrim,OldPrim,NewCut,OldCut,NPoint)
      ! old inherits from new (ok, so this isnt the way inheritance usually works...)
      implicit none
      integer        :: NewPrim,OldPrim,NewCut,OldCut,NPoint
      integer        :: HiCut,NewNumMatch,OldNumMatch,TotNumMatch,j,NSister
      type(PrimitiveAmplitude),pointer :: NewPrimAmp, OldPrimAmp
      type(UCutMatch),pointer          :: OldMatch,NewMatch

      NewPrimAmp=>PrimAmps(NewPrim)
      OldPrimAmp=>PrimAmps(OldPrim)
      do j=1,OldPrimAmp%NumSisters
         if (OldPrimAmp%Sisters(j) .eq. NewPrim) NSister=j
      enddo

      OldMatch=>OldPrimAmp%UCuts(NPoint)%Match(OldCut)
      NewMatch=>NewPrimAmp%UCuts(NPoint)%Match(NewCut)
      do HiCut=5,NPoint+1,-1
         OldNumMatch=OldMatch%Subt(HiCut)%NumMatch(NSister)
         NewNumMatch=NewMatch%Subt(HiCut)%NumMatch(0)
         OldMatch%Subt(HiCut)%NumMatch(NSister)=OldNumMatch+NewNumMatch
         TotNumMatch=OldMatch%Subt(HiCut)%NumMatch(NSister)
         
         OldMatch%Subt(HiCut)%MatchHiCuts(NSister,OldNumMatch+1:TotNumMatch) = &
              & NewMatch%Subt(HiCut)%MatchHiCuts(0,1:NewNumMatch)
         
         OldMatch%Subt(HiCut)%FirstHiProp(NSister,OldNumMatch+1:TotNumMatch) = &
              & NewMatch%Subt(HiCut)%FirstHiProp(0,1:NewNumMatch)

         OldMatch%Subt(HiCut)%MissHiProp(NSister,OldNumMatch+1:TotNumMatch,:) = &
              & NewMatch%Subt(HiCut)%MissHiProp(0,1:NewNumMatch,:)
      enddo

    end SUBROUTINE inherit_subtr

    

    SUBROUTINE ARE_TREES_EQUIV(Tree1, Tree2, isequiv)
    ! Routine to decide whether two tree processes are equivalent.
      type(TreeProcess),target  :: Tree1, Tree2
      logical, intent(out)      :: isequiv
      integer                   :: i, j
    
      isequiv=.false.
    
      ! Check they have the same number of particles.
      if (Tree1%NumPart .ne. Tree2%NumPart) return
    
      ! Check they have the same numbers of quarks
      if (Tree1%NumQua .ne. Tree2%NumQua) return
      ! Check they have the same numbers of scalars
      if (Tree1%NumSca .ne. Tree2%NumSca) return
      ! Check they have the same numbers of EW bosons
      ! NB no check on charge of W... (taken care of by check on flavors of quarks?)
      if (Tree1%NumV .ne. Tree2%NumV) return
      if (Tree1%NumW .ne. Tree2%NumW) return
    
      ! Check quarks have the same flavours
      do i = 1,Tree1%NumQua
         if (Tree1%Quarks(i)%PartType .ne. Tree2%Quarks(i)%PartType) return
      enddo
    
      ! Check they have the same number of gluons in the right place.
      do i = 0,Tree1%NumQua
         if (Tree1%NumGlu(i) .ne. Tree2%NumGlu(i)) return
         do j=1,Tree1%NumGlu(i)
            if (Tree1%Gluons(j)%ExtRef .ne. Tree2%Gluons(j)%ExtRef) return
         enddo
      enddo
    
    
      isequiv = .true.
    
    END SUBROUTINE ARE_TREES_EQUIV





END MODULE
