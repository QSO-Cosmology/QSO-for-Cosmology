! Quasar module created by Benetti and Bargiacchi 
!It was created by adapting the JLA.f90 file for QSO data.
!No subroutines or functions unrelated to the QSO analysis were removed; the file was only minimally modified to allow reading and 
!using the QSO data.
!
! Please cite 
! Benetti, Bargiacchi, Risaliti, Lusso, Signorini, Capozziello (2025)
! Quasar cosmology II: joint analyses with Cosmic Microwave Background  



    MODULE  QSO
    USE CosmologyTypes
    USE settings
    use CosmoTheory
    use Calculator_Cosmology
    use Likelihood_Cosmology
    IMPLICIT NONE

    !Modified by AL to have option of internal alpha, beta marginalization
    logical ::  QSO_marginalize = .false.
    REAL(mcp), allocatable ::  QSO_marge_grid(:), alpha_grid(:),beta_grid(:)
    integer ::  QSO_marge_steps = 0
    real(mcp)  QSO_step_width_alpha,  QSO_step_width_beta
    real(mcp), parameter ::  QSO_alpha_center =  0.14
    real(mcp), parameter ::  QSO_beta_center = 3.123
    integer ::  QSO_int_points = 1

    type, extends(TCosmoCalcLikelihood) ::  QSOLikelihood
    contains
    procedure :: LogLike =>  qso_LnLike
    end type  QSOLikelihood

    integer, parameter :: dl = mcp

    character(LEN=*), parameter ::  QSO_version =  'Nov_2021'
    logical, parameter :: allow_inv_cache = .false. !AL inverse cache does not work.. have not checked why.

    !Constants
    REAL(dl), PARAMETER, PRIVATE :: inv_twoPI = 1.0_dl / twopi
    CHARACTER, PARAMETER, PRIVATE :: uplo = 'U' !For LAPACK
    INTEGER, PARAMETER, PRIVATE :: max_idisp_datasets = 10
    INTEGER, PARAMETER, PRIVATE :: qsonamelen = 12
    REAL(dl), PARAMETER, PRIVATE :: h0cfac = 5*LOG10( 100.0/299792.458 )
    REAL(dl), PARAMETER, PRIVATE :: alphatol = 1E-10_dl, betatol = 1E-10_dl

    !Variables we will try to get from the ini file
    CHARACTER(LEN=30), PRIVATE :: name !Name of data set
    REAL(dl), PRIVATE :: pecz !Peculiar velocity error in z
    REAL(dl), DIMENSION( max_idisp_datasets ) :: intrinsicdisp !In magnitudes

    !Variables having to do with optional two-scripmt fit based
    ! on thirdvar cut
    LOGICAL, PRIVATE :: twoscriptmfit !Carry out two scriptm fit
    LOGICAL, PRIVATE :: has_thirdvar  !Data has third variable
    REAL(dl), PRIVATE :: scriptmcut !Cut in thirdvar between two scriptms

    !QSO data type
    TYPE, PRIVATE :: quasar
        CHARACTER(LEN=qsonamelen) :: name  !The name of the QSO
        REAL(dl) :: zhel, zcmb    !The heliocentric and CMB frame redshifts
        REAL(dl) :: z_var         !The variance of the redshift
        REAL(dl) :: mag           !The K-corrected peak magnitude
        REAL(dl) :: mag_var       !The variance of mag
        REAL(dl) :: stretch       !The light-curve fit stretch parameter
        REAL(dl) :: stretch_var   !The variance in the stretch
        REAL(dl) :: colour        !The colour of the QSO
        REAL(dl) :: colour_var    !The variance of colour
        REAL(dl) :: thirdvar      !Third variable for scripm split
        REAL(dl) :: thirdvar_var  !Variance in thirdvar
        REAL(dl) :: cov_mag_stretch !Covariance between mag and stretch
        REAL(dl) :: cov_mag_colour  !Covariance between mag and colour
        REAL(dl) :: cov_stretch_colour !Covariance between stretch and colour
        LOGICAL :: has_absdist    !This QSO has an absolute distance
        INTEGER  :: dataset       !Subset identifier if subset dependent intrinsic disp is used
    END TYPE quasar

    INTEGER, PUBLIC :: nqso  !Number of quasars
    TYPE(quasar), ALLOCATABLE, PRIVATE :: qsodata(:)  !Quasars data
    !Stores the parts of the error that can be pre-calculated
    REAL(dl), ALLOCATABLE, PRIVATE :: pre_vars(:)
    !Arrays which have 1 for QSO in set 1 (A1) or 2 (A2).  For twoscriptm fit
    REAL(dl), ALLOCATABLE, PRIVATE :: A1(:), A2(:)

    !Covariance matrix stuff
    ! If we have no covariance matrix at all, diag_errors is .TRUE.
    LOGICAL, PRIVATE :: diag_errors =        .TRUE.

    !Which components of the covariance matrix do we have
    LOGICAL, PRIVATE :: has_mag_covmat =            .FALSE.
    LOGICAL, PRIVATE :: has_stretch_covmat =        .FALSE.
    LOGICAL, PRIVATE :: has_colour_covmat =         .FALSE.
    LOGICAL, PRIVATE :: has_mag_stretch_covmat =    .FALSE.
    LOGICAL, PRIVATE :: has_mag_colour_covmat =     .FALSE.
    LOGICAL, PRIVATE :: has_stretch_colour_covmat = .FALSE.
    LOGICAL, PRIVATE :: alphabeta_covmat =          .FALSE.
    REAL(dl), ALLOCATABLE, PRIVATE :: mag_covmat(:,:), stretch_covmat(:,:)
    REAL(dl), ALLOCATABLE, PRIVATE :: colour_covmat(:,:), mag_stretch_covmat(:,:)
    REAL(dl), ALLOCATABLE, PRIVATE :: mag_colour_covmat(:,:)
    REAL(dl), ALLOCATABLE, PRIVATE :: stretch_colour_covmat(:,:)

    !Structure for holding absolute distance information for QSO
    LOGICAL, PRIVATE :: has_absdist =     .FALSE.
    INTEGER, PRIVATE :: nabsdist =         0
    TYPE, PRIVATE :: quasar_absdist
        CHARACTER(LEN=qsonamelen) :: name  !The name of the QSO
        REAL(dl) :: dl             !Distance in Mpc
        INTEGER :: index           !Index into qsodata
    END TYPE quasar_absdist
    TYPE( quasar_absdist ), ALLOCATABLE, PRIVATE :: qsoabsdist(:)

    !Other convenience variables
    REAL(dl), ALLOCATABLE, PRIVATE :: lumdists(:)
    REAL(dl), PRIVATE :: alpha_prev, beta_prev

    LOGICAL, PRIVATE :: first_inversion
    LOGICAL, PUBLIC :: qso_read = .FALSE.
    LOGICAL, PUBLIC :: qso_prepped = .FALSE.

    PRIVATE :: count_lines, read_qso_lc_data, read_cov_matrix
    PRIVATE :: read_qso_absdist_data, match_qso_absdist_indices
    PUBLIC :: qso_prep, qso_LnLike, qso_cleanup, read_qso_dataset,QSOLikelihood_Add

    CONTAINS


    subroutine QSOLikelihood_Add(LikeList, Ini)
    class(TLikelihoodList) :: LikeList
    class(TIniFile) :: ini
    Type(QSOLikelihood), pointer :: this
    character (LEN=:), allocatable:: qso_filename
    integer alpha_i, beta_i

    if (.not. Ini%Read_Logical('use_QSO',.false.)) return
    write(*,*) 'read use_QSO=T'
    allocate(this)
    this%LikelihoodType = 'QSO'
    this%name='QSO'
    this%needs_background_functions = .true.
    this%version = Ini%Read_String_Default('qso_version',QSO_version)
    QSO_marginalize = Ini%Read_Logical('QSO_marginalize',.false.)
    if (QSO_marginalize) then
        QSO_marge_steps = Ini%Read_Int('QSO_marge_steps',7)
        QSO_step_width_alpha = Ini%Read_Double('QSO_step_width_alpha',0.003d0)
        QSO_step_width_beta = Ini%Read_Double('QSO_step_width_beta',0.04d0)
        QSO_int_points=0
        allocate(alpha_grid((2*QSO_marge_steps+1)**2))
        allocate(beta_grid((2*QSO_marge_steps+1)**2))
        do alpha_i = - QSO_marge_steps, QSO_marge_steps
            do beta_i = - QSO_marge_steps, QSO_marge_steps
                if (alpha_i**2 + beta_i**2 <= QSO_marge_steps**2) then
                    QSO_int_points=QSO_int_points+1
                    alpha_grid(QSO_int_points) = QSO_alpha_center + alpha_i* QSO_step_width_alpha
                    beta_grid(QSO_int_points)  = QSO_beta_center + beta_i* QSO_step_width_beta
                end if
            end do
        end do
        allocate(QSO_marge_grid(QSO_int_points))
    else
        call this%loadParamNames(trim(DataDir)//'QSO.paramnames')  ! 
                                                                  
    end if
    call LikeList%Add(this)
    qso_filename = Ini%Read_String_Default('qso_dataset',trim(DataDir)//'qso.dataset') 
                                                                                    
    CALL read_qso_dataset(qso_filename )
    CALL qso_prep
    If (Feedback>0) WRITE(*,*) 'read qso dataset '//trim(qso_filename)

    end subroutine QSOLikelihood_Add

    !Counts the number of lines in an open file attached to lun,
    ! returning the number of lines in lines and the number of
    ! non-comment lines in noncommentlines, where a comment line
    ! is defined to start with a #
    !The file is rewound on exit
    SUBROUTINE count_lines( lun, lines, noncommentlines )
    IMPLICIT NONE
    INTEGER, INTENT(in) :: lun
    INTEGER, INTENT(out) :: lines, noncommentlines
    INTEGER, PARAMETER :: maxlines = 5000 !Maximum number allowed
    INTEGER :: i
    CHARACTER(LEN=80) :: inline, shiftline
    LOGICAL :: opened

    INTRINSIC ADJUSTL

    !Make sure the file is open
    INQUIRE( lun, OPENED=opened )
    IF (.NOT. opened) THEN
        WRITE(*,*) "File is not open in count_lines"
        STOP
    ENDIF

    !Now start reading
    lines = 0
    noncommentlines = 0
    DO i = 1, maxlines
        READ( lun, '(A)', ERR=2, END=100 ) inline
        lines = lines + 1
        shiftline = ADJUSTL( inline )
        IF ( shiftline(1:1) .NE. '#' ) noncommentlines = noncommentlines+1
    ENDDO
    GO TO 100

2   WRITE(*,*) "Error reading input file in count_lines"
    STOP

100 REWIND lun
    END SUBROUTINE count_lines

    !Reads the covariance matrix from a file, given the filename
    ! and the number of elements to expect
    !There are two possible formats supported
    ! These are: as one big block, and then as n by n individual elements
    ! The number of lines has to be the same as the number of QSO, and
    ! they have to be in the same order
    !Copied from settings::ReadMatrix
    SUBROUTINE read_cov_matrix(filename, mat, n)
    CHARACTER(LEN=*), INTENT(IN) :: filename
    INTEGER, INTENT(IN) :: n
    REAL(dl), INTENT(OUT) :: mat(n,n)
    INTEGER :: j,k, file_unit, nfile
    REAL(dl) :: tmp

    IF (Feedback > 2) WRITE(*,*) 'reading: '//trim(filename)
    OPEN( newunit=file_unit, FILE=TRIM(filename), FORM='formatted', &
        STATUS='old', ERR = 500 )

    READ (file_unit, '(I5)', END=200, ERR=100) nfile
    IF (nfile /= n) THEN
        WRITE (*,'("For file ",A," expected size ",I5," got ",I5)') &
            TRIM(filename), n, nfile
        STOP
    ENDIF

    DO j=1,n
        READ (file_unit,*, end = 200, err=100) mat(j,1:n)
    ENDDO

    GOTO 120

100 REWIND(file_unit)  !Try other possible format
    READ (file_unit, '(I5)', END=200, ERR=100) nfile

    DO j=1,n
        DO k=1,n
            READ (file_unit,*, end = 200) mat(j,k)
        END DO
    END DO

120 READ (file_unit,*, err = 150, end =150) tmp
    GOTO 200

150 CLOSE(file_unit)
    RETURN

200 WRITE (*,*) 'matrix file '//trim(filename)//' is the wrong size'
    WRITE (*,'("Expected: ",I5," by ",I5)') n,n
    STOP

500 WRITE (*,*) 'Failed to open cov matrix file ' // TRIM(filename)
    STOP

    END SUBROUTINE read_cov_matrix

    !------------------------------------------------------------
    ! Reads in a qso data file, given knowledge of the number
    !  of lines to expect.  Ignores lines that start with #.
    ! Input arguments:
    !  lun              The lun number of the file to read.  Must be already open
    !  nlines           The number of lines to expect in the file
    !  nnoncommentlines The number of non-comment lines in the file
    ! Output arguments:
    !  qsodata           The returned QSO data, of length nnoncommentlines
    ! Notes:
    !  The file is not rewound on exit
    !------------------------------------------------------------
    SUBROUTINE read_qso_lc_data( lun, nlines, nnoncommentlines, qsodata )
    IMPLICIT NONE
    INTEGER, INTENT(in) :: lun, nlines, nnoncommentlines
    TYPE(quasar), INTENT(out) :: qsodata(nnoncommentlines)

    CHARACTER(LEN=80) :: inline, shiftline
    INTEGER:: i,count
    REAL :: dz, dm, ds, dc, dt
    LOGICAL :: opened

    INTRINSIC ADJUSTL

    INQUIRE( lun, OPENED=opened )
    IF (.NOT. opened) THEN
        WRITE(*,*) "File is not open in count_lines"
        STOP
    ENDIF

    count = 1
    has_thirdvar = .FALSE.
    qsodata%has_absdist = .FALSE.
    DO i=1,nlines
        !Read in line non-advancing
        READ (lun, '(A)', ERR = 20, END = 20) inline
        shiftline = ADJUSTL( inline )
        IF (shiftline(1:1) .EQ. '#') CYCLE

        BACKSPACE lun

        !We have a few formats to try.  First, there is the very
        ! long format with thirdvar and dataset.  If that fails,
        ! try without data set.  If that fails, try without
        ! thirdvar but with dataset, and finally with neither

        !A further complication is that if one line has thirdvar,
        ! they had better all have them or else ugliness will probably
        ! result
        READ (lun, *, ERR=20, END=20) &
            qsodata(count)%name, qsodata(count)%zcmb, qsodata(count)%zhel,&
            dz, qsodata(count)%mag, dm, qsodata(count)%stretch, ds, &
            qsodata(count)%colour,dc,qsodata(count)%thirdvar, dt,&
            qsodata(count)%cov_mag_stretch,&
            qsodata(count)%cov_mag_colour,qsodata(count)%cov_stretch_colour,&
            qsodata(count)%dataset
        IF ( (count .GT. 1) .AND. (.NOT. has_thirdvar) ) THEN
            WRITE(*,*) "Problem with third variable read"
            STOP
        ENDIF
        has_thirdvar = .TRUE.
        GOTO 10  !Success

        !That didn't work. Try without dataset.  First, undo the
        ! previous.  It should be 2 records out of place because
        ! we read over into the next line
20      BACKSPACE lun
        BACKSPACE lun
        READ (lun, *, ERR=30, END=30) &
            qsodata(count)%name, qsodata(count)%zcmb, qsodata(count)%zhel,&
            dz, qsodata(count)%mag, dm, qsodata(count)%stretch, ds, &
            qsodata(count)%colour,dc,qsodata(count)%thirdvar, dt,&
            qsodata(count)%cov_mag_stretch,&
            qsodata(count)%cov_mag_colour,qsodata(count)%cov_stretch_colour
        IF ( (count .GT. 1) .AND. (.NOT. has_thirdvar) ) THEN
            WRITE(*,*) "Problem with third variable read"
            STOP
        ENDIF
        has_thirdvar = .TRUE.
        GOTO 10  !Success

        !Ok, maybe there's no thirdvar
30      BACKSPACE lun
        BACKSPACE lun
        READ (lun, *, ERR=40, END=40) &
            qsodata(count)%name, qsodata(count)%zcmb, qsodata(count)%zhel,&
            dz, qsodata(count)%mag, dm, qsodata(count)%stretch, ds, &
            qsodata(count)%colour,dc,qsodata(count)%thirdvar, dt,&
            qsodata(count)%cov_mag_stretch,&
            qsodata(count)%cov_mag_colour,qsodata(count)%cov_stretch_colour,&
            qsodata(count)%dataset
        IF ( (count .GT. 1) .AND. (has_thirdvar) ) THEN
            WRITE(*,*) "Problem with third variable read"
            STOP
        ENDIF
        qsodata(count)%thirdvar = 0.0
        dt = 0.0
        qsodata(count)%dataset = 0

        !Still?
        !Ok, maybe there's no thirdvar and no dataset
40      BACKSPACE lun
        BACKSPACE lun
        READ (lun, *, ERR=60, END=50) &
            qsodata(count)%name, qsodata(count)%zcmb, qsodata(count)%zhel,&
            dz, qsodata(count)%mag, dm, qsodata(count)%stretch, ds, &
            qsodata(count)%colour,dc,qsodata(count)%thirdvar, dt,&
            qsodata(count)%cov_mag_stretch,&
            qsodata(count)%cov_mag_colour,qsodata(count)%cov_stretch_colour
        IF ( (count .GT. 1) .AND. (has_thirdvar) ) THEN
            WRITE(*,*) "Problem with third variable read"
            STOP
        ENDIF
        qsodata(count)%thirdvar = 0.0
        dt = 0.0
        qsodata(count)%dataset = 0

10      qsodata(count)%z_var = dz**2
        qsodata(count)%mag_var = dm**2
        qsodata(count)%stretch_var = ds**2
        qsodata(count)%colour_var = dc**2
        qsodata(count)%thirdvar_var = dt**2
        !qsodata(count)%thirdvar = 6
        count = count+1
    END DO
    RETURN

50  WRITE(*,'("File ended unexpectedly on line ",I3," expecting ",I3)') i,nlines
    STOP

60  WRITE(*,*) 'Error reading in input data with: ',inline
    STOP

    END SUBROUTINE read_qso_lc_data

    !------------------------------------------------------------
    ! Read in absolute distance info, given knowledge of the number
    !  of lines to expect.  Ignores lines that start with #.
    ! Input arguments:
    !  lun              The lun number of the file to read.  Must be already open
    !  nlines           The number of lines to expect in the file
    !  nnoncommentlines The number of non-comment lines in the file
    ! Output arguments:
    !  qsoabsdist        The absolute distance data, of length nnoncommentlines
    ! Notes:
    !  The file is not rewound on exit
    !------------------------------------------------------------
    SUBROUTINE read_qso_absdist_data( lun, nlines, nnoncommentlines, qsoabsdist )
    IMPLICIT NONE
    INTEGER, INTENT(in) :: lun, nlines, nnoncommentlines
    TYPE(quasar_absdist), INTENT(out) :: qsoabsdist(nnoncommentlines)

    CHARACTER(LEN=80) :: inline, shiftline
    INTEGER:: i,count
    LOGICAL :: opened

    INTRINSIC ADJUSTL

    INQUIRE( lun, OPENED=opened )
    IF (.NOT. opened) THEN
        WRITE(*,*) "File is not open in count_lines"
        STOP
    ENDIF

    count = 1
    DO i=1,nlines
        !Read in line non-advancing mode
        READ (lun, '(A)', ERR = 140, END = 130) inline
        shiftline = ADJUSTL( inline )
        IF (shiftline(1:1) .EQ. '#') CYCLE

        BACKSPACE lun

        READ (lun, *, ERR=140, END=130) &
            qsoabsdist(count)%name, qsoabsdist(count)%dl
        count = count+1
    END DO
    RETURN

130 WRITE(*,'("File ended unexpectedly on line ",I3," expecting ",I3)') i,nlines
    STOP

140 WRITE(*,*) 'Error reading in input data with: ',inline
    STOP

    END SUBROUTINE read_qso_absdist_data

    !------------------------------------------------------------
    ! Match absdist info into qsoinfo by searching on names
    ! Arguments:
    !  qsodata          QSO data. Modified on output
    !  qsoabsdist       Absolute distance data.  Modified on output
    !------------------------------------------------------------
    SUBROUTINE match_qso_absdist_indices( qsodata, qsoabsdist )
    IMPLICIT NONE
    TYPE(quasar), INTENT(INOUT) :: qsodata(:)
    TYPE(quasar_absdist), INTENT(INOUT) :: qsoabsdist(:)
    CHARACTER(LEN=qsonamelen) :: currname
    INTEGER :: nqso, nabsdist, i, j

    nqso = SIZE( qsodata )
    nabsdist = SIZE( qsoabsdist )

    IF (nqso == 0) THEN
        WRITE (*,*) "ERROR -- qsodata has zero length"
        STOP
    ENDIF
    IF (nabsdist == 0) THEN
        WRITE (*,*) "ERROR -- qsoabsdist has zero length"
        STOP
    ENDIF

    !We do this slowly and inefficiently because we only have
    ! to do it once, and because string manipulation is such
    ! a nightmare in Fortran
    qsoabsdist%index = -1
    oloop:    DO i = 1, nabsdist
        currname = qsoabsdist(i)%name
        DO j = 1, nqso
            IF ( qsodata(j)%name .EQ. currname ) THEN
                qsodata(j)%has_absdist = .TRUE.
                qsoabsdist(i)%index = j
                CYCLE oloop
            ENDIF
        ENDDO
    ENDDO oloop

    !Make sure we found them all
    DO i=1,nabsdist
        IF ( qsoabsdist(i)%index .LT. 0 ) THEN
            WRITE (*,'("Failed to match ",A," to full qso list")') &
                qsoabsdist(i)%name
            STOP
        ENDIF
    ENDDO

    END SUBROUTINE match_qso_absdist_indices

    !------------------------------------------------------------
    ! The public interface to reading data files
    ! This gets information from the .ini file and reads the data file
    ! Arguments:
    !  filename        The name of the .ini file specifying the QSO dataset
    !------------------------------------------------------------
    SUBROUTINE read_qso_dataset(filename )
    IMPLICIT NONE
    CHARACTER(LEN=*), INTENT(in) :: filename
    CHARACTER(LEN=:), allocatable :: covfile
    CHARACTER(LEN=:), allocatable :: data_file, absdist_file
    INTEGER :: nlines, i
    REAL(dl) :: idisp_zero !Value for unspecified dataset numbers
    LOGICAL, DIMENSION( max_idisp_datasets ) :: idispdataset
    Type(TSettingIni) :: Ini
    integer file_unit

    IF (qso_read) STOP 'Error -- qso data already read'

    !Process the Ini file
    CALL Ini%Open(filename)

    name = Ini%Read_String( 'name', .FALSE. )
    data_file = Ini%Read_String_Default('data_file',trim(DataDir)//'lcparam_full_long_zhel.txt') 

    has_absdist = Ini%Read_Logical( 'absdist_file',.FALSE.)
    pecz = Ini%Read_Double( 'pecz', 0.001D0 )

    twoscriptmfit = Ini%Read_Logical('twoscriptmfit',.FALSE.)
    IF ( twoscriptmfit ) scriptmcut = Ini%Read_Double('scriptmcut',10.0d0)

    !Handle intrinsic dispersion
    !The individual values are intrinsicdisp0 -- intrinsicdisp9
    idisp_zero = Ini%Read_Double( 'intrinsicdisp', 0.13_dl )
    idispdataset = .FALSE.
    DO i=1, max_idisp_datasets
        intrinsicdisp(i) = Ini%Read_Double(numcat('intrinsicdisp',i-1),&
            idisp_zero)
        IF (intrinsicdisp(i) .NE. idisp_zero) idispdataset(i)=.TRUE.
    END DO

    !Now read the actual QSO data
    OPEN( newunit=file_unit, FILE=TRIM(data_file), FORM='formatted', &
        STATUS='old', ERR = 500 )
    !Find the number of lines
    CALL count_lines( file_unit, nlines, nqso )
    ALLOCATE( qsodata(nqso) )
    CALL read_qso_lc_data( file_unit, nlines, nqso, qsodata )
    CLOSE( file_unit )

    !Make sure we have thirdvar if we need it
    IF ( twoscriptmfit .AND. (.NOT. has_thirdvar) ) THEN
        WRITE(*,*) "twoscriptmfit was set but thirdvar information not present"
        STOP
    ENDIF

    !Absolute distance
    IF ( has_absdist ) THEN
        OPEN( newunit=file_unit, FILE=TRIM(absdist_file), FORM='formatted', &
            STATUS='old', ERR = 500 )
        !Find the number of lines
        CALL count_lines( file_unit, nlines, nabsdist )
        ALLOCATE( qsoabsdist(nabsdist) )
        CALL read_qso_absdist_data( file_unit, nlines, nabsdist, qsoabsdist )
        CLOSE( file_unit )
        CALL match_qso_absdist_indices( qsodata, qsoabsdist )
    ENDIF

    !Handle covariance matrix stuff
    has_mag_covmat=Ini%Read_Logical( 'has_mag_covmat', .FALSE. )
    has_stretch_covmat=Ini%Read_Logical( 'has_stretch_covmat', .FALSE. )
    has_colour_covmat=Ini%Read_Logical( 'has_colour_covmat', .FALSE. )
    has_mag_stretch_covmat=Ini%Read_Logical('has_mag_stretch_covmat',.FALSE.)
    has_mag_colour_covmat=Ini%Read_Logical( 'has_mag_colour_covmat',.FALSE. )
    has_stretch_colour_covmat = &
        Ini%Read_Logical( 'has_stretch_colour_covmat',.FALSE. )
    alphabeta_covmat = ( has_stretch_covmat .OR. has_colour_covmat .OR. &
        has_mag_stretch_covmat .OR. has_mag_colour_covmat .OR. &
        has_stretch_colour_covmat )

    !First test for covmat
    IF ( has_mag_covmat .OR. has_stretch_covmat .OR. has_colour_covmat .OR. &
        has_mag_stretch_covmat .OR. has_mag_colour_covmat .OR. &
        has_stretch_colour_covmat ) THEN
    diag_errors = .FALSE.

    !Now Read in the covariance matricies
    IF (has_mag_covmat) THEN
        covfile = Ini%Read_String('mag_covmat_file',.TRUE.)
        ALLOCATE( mag_covmat( nqso, nqso ) )
        CALL read_cov_matrix( covfile, mag_covmat, nqso )
    ENDIF
    IF (has_stretch_covmat) THEN
        covfile = Ini%Read_String('stretch_covmat_file',.TRUE.)
        ALLOCATE( stretch_covmat( nqso, nqso ) )
        CALL read_cov_matrix( covfile, stretch_covmat, nqso )
    ENDIF
    IF (has_colour_covmat) THEN
        covfile = Ini%Read_String('colour_covmat_file',.TRUE.)
        ALLOCATE( colour_covmat( nqso, nqso ) )
        CALL read_cov_matrix( covfile, colour_covmat, nqso )
    ENDIF
    IF (has_mag_stretch_covmat) THEN
        covfile = Ini%Read_String('mag_stretch_covmat_file',.TRUE.)
        ALLOCATE( mag_stretch_covmat( nqso, nqso ) )
        CALL read_cov_matrix( covfile, mag_stretch_covmat, nqso )
    ENDIF
    IF (has_mag_colour_covmat) THEN
        covfile = Ini%Read_String('mag_colour_covmat_file',.TRUE.)
        ALLOCATE( mag_colour_covmat( nqso, nqso ) )
        CALL read_cov_matrix( covfile, mag_colour_covmat, nqso )
    ENDIF
    IF (has_stretch_colour_covmat) THEN
        covfile = Ini%Read_String('stretch_colour_covmat_file',.TRUE.)
        ALLOCATE( stretch_colour_covmat( nqso, nqso ) )
        CALL read_cov_matrix( covfile, stretch_colour_covmat, nqso )
    ENDIF
    ELSE
        diag_errors = .TRUE.
    END IF

    CALL Ini%Close()

    IF (Feedback > 1) THEN
        WRITE(*,'("qso dataset name: ",A)') TRIM(name)
        WRITE(*,'(" qso data file: ",A)') TRIM(data_file)
        WRITE(*,'(" Number of qso read: ",I4)') nqso
    ENDIF

    IF (Feedback > 2) THEN
        WRITE(*,'(" qso pec z: ",F6.3)') pecz
        WRITE(*,'(" qso default sigma int: ",F6.3)') idisp_zero
        DO i=1, max_idisp_datasets
            IF ( idispdataset(i)) &
                WRITE(*,'(" qso sigma int for dataset ",I2,": ",F6.3)') &
                i-1,intrinsicdisp(i)
        END DO
        IF (has_absdist) THEN
            WRITE (*,'(" Number of qso with absolute distances: ",I4)') &
                nabsdist
            IF (Feedback>2 .AND. (nabsdist .LT. 10)) THEN
                DO i=1,nabsdist
                    WRITE(*,'("   Name: ",A12," dist: ",F8.2)') &
                        qsoabsdist(i)%name,qsoabsdist(i)%dl
                ENDDO
            ENDIF
        ENDIF
        IF (twoscriptmfit) THEN
            WRITE (*,'("Doing two-scriptm fit with cut: ",F7.3)') scriptmcut
        ENDIF
        IF (has_mag_covmat) WRITE (*,*) " Has mag covariance matrix"
        IF (has_stretch_covmat) WRITE (*,*) " Has stretch covariance matrix"
        IF (has_colour_covmat) WRITE (*,*) " Has colour covariance matrix"
        IF (has_mag_stretch_covmat) &
            WRITE (*,*) " Has mag-stretch covariance matrix"
        IF (has_mag_colour_covmat) &
            WRITE (*,*) " Has mag-colour covariance matrix"
        IF (has_stretch_colour_covmat) &
            WRITE (*,*) " Has stretch_colour covariance matrix"
    ENDIF

    first_inversion = .true.
    qso_read = .TRUE.
    qso_prepped = .FALSE.
    RETURN

500 WRITE(*,*) 'Error reading ' // data_file
    STOP

    END SUBROUTINE read_qso_dataset

    !-------------------------------------------------------------
    !Inverts the covariance matrix.  Assumes all sorts of stuff
    ! is pre-allocated and pre-filled.  Pre_vars must already have
    ! the intrinsic dispersion, redshift error, mag error.
    ! Has a check to see if the previous cov matrix can be reused
    !-------------------------------------------------------------
    SUBROUTINE invert_covariance_matrix(invcovmat, alpha, beta, status )
    IMPLICIT NONE
    CHARACTER(LEN=*), PARAMETER :: cholerrfmt = &
        '("Error computing cholesky decomposition for ",F6.3,2X,F6.3)'
    CHARACTER(LEN=*), PARAMETER :: cholinvfmt = &
        '("Error inverting cov matrix for ",F6.3,2X,F6.3)'
    CHARACTER(LEN=*), PARAMETER :: cholsolfmt = &
        '("Error forming inv matrix product for ",F6.3,2X,F6.3)'

    REAL(dl), INTENT(IN) :: alpha, beta
    INTEGER, INTENT(INOUT) :: status
    REAL(dl) :: invcovmat(:,:)

    INTEGER :: I
    REAL(dl) :: alphasq, betasq, alphabeta

    !Quick exit check
    !Note that first_inversion can't be true if the first one
    ! failed (has status != 0).
    IF (.NOT. first_inversion .and. allow_inv_cache) THEN
        IF (.NOT. alphabeta_covmat) THEN
            !covmatrix doesn't depend on alpha/beta, has already been
            ! inverted once.
            status = 0
            RETURN
        ELSE IF ( (ABS(alpha-alpha_prev) .LT. alphatol) .AND. &
            ( ABS(beta-beta_prev) .LT. betatol ) ) THEN
        !Previous invcovmatrix is close enough
        status = 0
        RETURN
        ENDIF
    ENDIF

    alphasq = alpha * alpha
    betasq = beta * beta
    alphabeta = alpha * beta

    IF (diag_errors) STOP 'Error -- asking to invert with diagonal errors'

    !Build the covariance matrix, then invert it
    IF (has_mag_covmat) THEN
        invcovmat = mag_covmat
    ELSE
        invcovmat = 0.0_dl
    END IF
    IF (has_stretch_covmat) invcovmat = invcovmat + &
        alphasq * stretch_covmat
    IF (has_colour_covmat) invcovmat = invcovmat + &
        betasq * colour_covmat
    IF (has_mag_stretch_covmat) invcovmat = invcovmat + 2.0 * alpha * mag_stretch_covmat
    IF (has_mag_colour_covmat) invcovmat = invcovmat - 2.0 * beta * mag_colour_covmat
    IF (has_stretch_colour_covmat) invcovmat = invcovmat - 2.0 * alphabeta * stretch_colour_covmat

    !Update the diagonal terms
    DO I=1, nqso
        invcovmat(I,I) = invcovmat(I,I) + pre_vars(I) &
            + alphasq * qsodata(I)%stretch_var &
            + betasq  * qsodata(I)%colour_var &
            + 2.0 * alpha * qsodata(I)%cov_mag_stretch &
            - 2.0 * beta * qsodata(I)%cov_mag_colour &
            - 2.0 * alphabeta * qsodata(I)%cov_stretch_colour
    END DO

    !Factor into Cholesky form, overwriting the input matrix
    CALL DPOTRF(uplo,nqso,invcovmat,nqso,status)
    IF ( status .NE. 0 ) THEN
        WRITE(*,cholerrfmt) alpha, beta
        RETURN
    END IF

    !Now invert
    !If we could get away with the relative chisquare
    ! this could be done faster and more accurately
    ! by solving the system V*x = diffmag for x to get
    ! V^-1 * diffmag.  But, with the introduction of alpha, beta
    ! this _doesn't_ work, so we need the actual elements of
    ! the inverse covariance matrix.  The point is that the
    ! amarg_E parameter depends on the sum of the elements of
    ! the inverse covariance matrix, and therefore is different
    ! for different values of alpha and beta.
    !Note that DPOTRI only makes half of the matrix correct,
    ! so we have to be careful in what follows
    CALL DPOTRI(uplo,nqso,invcovmat,nqso,status)
    IF ( status .NE. 0 ) THEN
        WRITE(*,cholinvfmt) alpha, beta

        RETURN
    END IF

    first_inversion = .FALSE.
    alpha_prev = alpha
    beta_prev  = beta

    END SUBROUTINE invert_covariance_matrix


    !------------------------------------------------------------
    ! Prepares the data for fitting by pre-calculating the parts of
    !  the errors that can be done ahead of time.
    ! ReadJLADataset must have been read before calling this
    !------------------------------------------------------------
    SUBROUTINE qso_prep
    IMPLICIT NONE

    CHARACTER(LEN=*), PARAMETER :: qsoheadfmt = '(1X,A10,9(1X,A8))'
    CHARACTER(LEN=*), PARAMETER :: qsodatfmt = '(1X,A10,9(1X,F8.4))'
    CHARACTER(LEN=*), PARAMETER :: qsodatfmt2 = '(1X,A10,11(1X,F8.4))'
    CHARACTER(LEN=*), PARAMETER :: datafile = 'data/qso_data.dat'
    ! dz multiplicative factor
    REAL(dl), PARAMETER :: zfacsq = 25.0/(LOG(10.0))**2

    REAL(dl) ::  intrinsicsq(max_idisp_datasets)
    INTEGER ::  i
    LOGICAL :: has_A1, has_A2

    intrinsicsq = intrinsicdisp**2

    IF (.NOT. qso_read) STOP 'qso data was not read in'
    IF (nqso < 1) STOP 'No qso data read'

    IF ( MAXVAL( qsodata%dataset ) .GE. max_idisp_datasets ) THEN
        WRITE(*,*) 'Invalid dataset number ',MAXVAL(qsodata%dataset)
        WRITE(*,*) ' Maximum allowed is ',max_idisp_datasets
    END IF
    IF ( MINVAL( qsodata%dataset ) .LT. 0 ) THEN
        WRITE(*,*) 'Invalid dataset number ',MINVAL(qsodata%dataset)
        WRITE(*,*) ' Maximum allowed is 0'
    END IF

    !Pre-calculate errors as much as we can
    !The include the magnitude error, the peculiar velocity
    ! error, and the intrinsic dispersion.
    !We don't treat the pec-z/redshift errors completely correctly,
    ! using the empty-universe expansion.  However, the redshift errors
    ! are really only important at low-z with current samples (where
    ! peculiar velocities dominate) so this is a very good approximation.
    ! If photometric redshifts are ever used, this may have to be
    ! modified
    !The redshift error is irrelevant for QSO with absolute distances
    ALLOCATE( pre_vars(nqso) )
    pre_vars = qsodata%mag_var + intrinsicsq(qsodata%dataset+1)
    DO i=1,nqso
        IF (.NOT. qsodata(i)%has_absdist) THEN
            pre_vars(i) = pre_vars(i) + &
                zfacsq * pecz**2 * &
                ( (1.0 + qsodata(i)%zcmb)/&
                (qsodata(i)%zcmb*(1+0.5*qsodata(i)%zcmb)) )**2
        ENDIF
    ENDDO
    ALLOCATE(lumdists(nqso))

    IF (twoscriptmfit) THEN
        ALLOCATE( A1(nqso), A2(nqso) )
        has_A1 = .TRUE.
        has_A2 = .FALSE.
        !Assign A1 and A2 as needed
        DO i=1, nqso
            IF (qsodata(i)%thirdvar .LE. scriptmcut ) THEN
                A1(i) = 1.0_dl
                A2(i) = 0.0_dl
                has_A1 = .TRUE.
            ELSE
                A1(i) = 0.0_dl
                A2(i) = 1.0_dl
                has_A2 = .TRUE.
            END IF
        END DO

        IF (.NOT. has_A1) THEN
            !Swap
            A1 = A2
            A2(:) = 0.0_dl
            twoscriptmfit = .FALSE.
            has_A1 = .TRUE.
            has_A2 = .FALSE.
        ENDIF

        IF (.NOT. has_A2) THEN
            IF (Feedback > 2) THEN
                WRITE(*,*) "No qso present in scriptm set 2"
                WRITE(*,*) "De-activating two scriptm fit"
            ENDIF
            twoscriptmfit = .FALSE.
        ENDIF
    ENDIF

    IF (Feedback > 3) THEN
        !Write out summary of QSO info
        WRITE(*,*) "Summary of quasar data: "
        IF (twoscriptmfit) THEN
            WRITE(*,qsoheadfmt) "Name","zhel","dz","mag","dmag", &
                "s","ds","c","dc","t","dt","pre_err"
            DO i = 1, nqso
                WRITE(*,qsodatfmt2) qsodata(i)%name,qsodata(i)%zhel,&
                    SQRT(qsodata(i)%z_var),qsodata(i)%mag,SQRT(qsodata(i)%mag_var),&
                    qsodata(i)%stretch,SQRT(qsodata(i)%stretch_var),&
                    qsodata(i)%colour,SQRT(qsodata(i)%colour_var),&
                    qsodata(i)%thirdvar,SQRT(qsodata(i)%thirdvar_var),&
                    SQRT(pre_vars(i))
            END DO
        ELSE
            WRITE(*,qsoheadfmt) "Name","zhel","dz","mag","dmag", &
                "s","ds","c","dc","pre_err"
            DO i = 1, nqso
                WRITE(*,qsodatfmt) qsodata(i)%name,qsodata(i)%zhel,&
                    SQRT(qsodata(i)%z_var),qsodata(i)%mag,SQRT(qsodata(i)%mag_var),&
                    qsodata(i)%stretch,SQRT(qsodata(i)%stretch_var),&
                    qsodata(i)%colour,&
                    SQRT(qsodata(i)%colour_var),SQRT(pre_vars(i))
            END DO
        ENDIF
    ENDIF

    qso_prepped = .TRUE.
    first_inversion = .TRUE.
    RETURN
500 WRITE(*,*) 'Error reading ' // datafile
    STOP
    END SUBROUTINE qso_prep

    !------------------------------------------------------------
    ! Clean up routine -- de-allocates memory
    !------------------------------------------------------------
    SUBROUTINE qso_cleanup
    IF ( ALLOCATED( qsodata ) ) DEALLOCATE( qsodata )
    IF ( ALLOCATED( pre_vars ) ) DEALLOCATE( pre_vars )
    IF ( ALLOCATED( A1 ) ) DEALLOCATE( A1 )
    IF ( ALLOCATED( A2 ) ) DEALLOCATE( A2 )
    IF ( ALLOCATED( lumdists ) ) DEALLOCATE( lumdists )
    IF ( ALLOCATED( mag_covmat ) ) DEALLOCATE( mag_covmat )
    IF ( ALLOCATED( stretch_covmat ) ) DEALLOCATE( stretch_covmat )
    IF ( ALLOCATED( colour_covmat ) ) DEALLOCATE( colour_covmat )
    IF ( ALLOCATED( mag_stretch_covmat ) ) DEALLOCATE( mag_stretch_covmat )
    IF ( ALLOCATED( mag_colour_covmat ) ) DEALLOCATE( mag_colour_covmat )
    IF ( ALLOCATED( stretch_colour_covmat ) ) &
        DEALLOCATE( stretch_colour_covmat )
    IF ( ALLOCATED( qsoabsdist ) ) DEALLOCATE( qsoabsdist )

    qso_prepped = .FALSE.
    END SUBROUTINE qso_cleanup

    !------------------------------------------------------------
    ! Routine for calculating the log-likelihood of the JLA
    ! data.  You _have_ to call this just after calling CAMB
    ! with the model you want to evaluate against.   It's assumed
    ! that you have called read_jla_dataset and jla_prep before
    ! trying this.
    !
    ! Arguments:
    !  CMB             Has the values of alpha and beta
    ! Returns:
    !  The negative of the log likelihood of the QSO data with respect
    !  to the current mode
    !------------------------------------------------------------

    FUNCTION  QSO_alpha_beta_like(alpha, beta,  lumdists)
    real(mcp) :: QSO_alpha_beta_like
    CHARACTER(LEN=*), PARAMETER :: invfmt = &
        '("Error inverting cov matrix for ",F6.3,2X,F6.3)'

    INTEGER :: i, status
    real(dl) :: lumdists(nqso)
    REAL(dl) :: alpha, beta
    !We form an estimate for scriptm to improve numerical
    ! accuracy in our marginaliztion
    REAL(dl) :: estimated_scriptm, wtval
    REAL(dl) :: chisq !Utility variables
    REAL(dl) :: alphasq, betasq, alphabeta !More utility variables
    REAL(dl) :: amarg_A, amarg_B, amarg_C
    REAL(dl) :: amarg_D, amarg_E, amarg_F, tempG !Marginalization params
    real(dl) :: diffmag(nqso),invvars(nqso)
    real(dl), allocatable :: invcovmat(:,:)

    allocate(invcovmat(nqso,nqso))

    alphasq   = alpha*alpha
    betasq    = beta*beta
    alphabeta = alpha*beta

    !We want to get a first guess at scriptm to improve the
    ! numerical precision of the results.  We'll do this ignoring
    ! the covariance matrix and ignoring if there are two scriptms
    ! to deal with
    invvars = 1.0 / ( pre_vars + alphasq * qsodata%stretch_var &
        + betasq * qsodata%colour_var &
        + 2.0 * alpha * qsodata%cov_mag_stretch &
        - 2.0 * beta * qsodata%cov_mag_colour &
        - 2.0 * alphabeta * qsodata%cov_stretch_colour )

    wtval = SUM( invvars )
    estimated_scriptm= SUM( (qsodata%mag - lumdists)*invvars ) / wtval

    ! k= estimated_scriptm - 25
    diffmag = qsodata%mag - lumdists + alpha*( qsodata%stretch ) &
        - beta * qsodata%colour - estimated_scriptm

    IF ( diag_errors ) THEN
        amarg_A = SUM( invvars * diffmag**2 )
        IF ( twoscriptmfit ) THEN
            amarg_B = SUM( invvars * diffmag * A1)
            amarg_C = SUM( invvars * diffmag * A2)
            amarg_D = 0.0
            amarg_E = DOT_PRODUCT( invvars, A1 )
            amarg_F = DOT_PRODUCT( invvars, A2 )
        ELSE
            amarg_B = SUM( invvars * diffmag )
            amarg_E = wtval
        ENDIF
    ELSE
        !Unfortunately, we actually need the covariance matrix,
        ! and can't get away with evaluating terms this
        ! V^-1 * x = y by solving V * y = x.  This costs us in performance
        ! and accuracy, but such is life
        CALL invert_covariance_matrix(invcovmat, alpha,beta,status)
        IF (status .NE. 0) THEN
            WRITE (*,invfmt) alpha,beta
            QSO_alpha_beta_like = logZero
            !            IF (.NOT. diag_errors) THEN
            !                DEALLOCATE( invcovmat)
            ! END IF
            RETURN
        ENDIF

        !Now find the amarg_ parameters
        !We re-use the invvars variable to hold the intermediate product
        !which is sort of naughty
        ! invvars = V^-1 * diffmag (invvars = 1.0*invcovmat*diffmag+0*invvars)
        CALL DSYMV(uplo,nqso,1.0d0,invcovmat,nqso,diffmag,1,0.0d0,invvars,1)

        amarg_A = DOT_PRODUCT( diffmag, invvars ) ! diffmag*V^-1*diffmag

        IF (twoscriptmfit) THEN
            amarg_B = DOT_PRODUCT( invvars, A1 ) !diffmag*V^-1*A1
            amarg_C = DOT_PRODUCT( invvars, A2 ) !diffmag*V^-1*A2

            !Be naughty again and stick V^-1 * A1 in invvars
            CALL DSYMV(uplo,nqso,1.0d0,invcovmat,nqso,A1,1,0.0d0,invvars,1)
            amarg_D = DOT_PRODUCT( invvars, A2 ) !A2*V^-1*A1
            amarg_E = DOT_PRODUCT( invvars, A1 ) !A1*V^-1*A1
            ! now V^-1 * A2
            CALL DSYMV(uplo,nqso,1.0d0,invcovmat,nqso,A2,1,0.0d0,invvars,1)
            amarg_F = DOT_PRODUCT( invvars, A2 ) !A2*V^-1*A2
        ELSE
            amarg_B = SUM( invvars ) !GB = 1 * V^-1 * diffmag
            !amarg_E requires a little care since only half of the
            !matrix is correct if we used the full covariance matrix
            ! (which half depends on UPLO)
            !GE = 1 * V^-1 * 1
            amarg_C = 0.0_dl
            amarg_D = 0.0_dl
            amarg_E = 0.0_dl
            amarg_F = 0.0_dl
            IF ( uplo .EQ. 'U' ) THEN
                DO I=1,nqso
                    amarg_E = amarg_E + invcovmat(I,I) + 2.0_dl*SUM( invcovmat( 1:I-1, I ) )
                END DO
            ELSE
                DO I=1,nqso
                    amarg_E = amarg_E + invcovmat(I,I) + 2.0_dl*SUM( invcovmat( I+1:nqso, I ) )
                END DO
            END IF
        ENDIF
    END IF

    IF (twoscriptmfit) THEN
        !Messy case
        tempG = amarg_F - amarg_D*amarg_D/amarg_E;
        IF (tempG .LE. 0.0) THEN
            WRITE(*,*) "Twoscriptm assumption violation"
            STOP
        ENDIF
        chisq = amarg_A + LOG( amarg_E*inv_twopi ) + &
            LOG( tempG * inv_twopi ) - amarg_C*amarg_C/tempG - &
            amarg_B*amarg_B*amarg_F / ( amarg_E*tempG ) + 2.0*amarg_B*amarg_C*amarg_D/(amarg_E*tempG )
    ELSE
        chisq = amarg_A + LOG( amarg_E*inv_twoPI ) - amarg_B**2/amarg_E
    ENDIF
    QSO_alpha_beta_like = chisq / 2  !Negative log likelihood

    IF (Feedback > 1 .and. .not. QSO_marginalize) THEN
        IF (Feedback > 2) THEN
            IF (twoscriptmfit) THEN
                WRITE(*,'(" QSO alpha: ",F7.4," beta: ",F7.4," scriptm1: ",F9.4, "scriptm2: ",F9.4)') &
                    alpha,beta,(amarg_B*amarg_F-amarg_C*amarg_D)/tempG,&
                    (amarg_C*amarg_E-amarg_B*amarg_D)/tempG
            ELSE
                WRITE(*,'(" QSO alpha: ",F7.4," beta: ",F9.4," scriptm: ",F9.4)') &
                    alpha,beta,-amarg_B/amarg_E
            ENDIF
        END IF
        WRITE(*,'(" QSO chi2: ",F7.2," for ",I5," QSO")') chisq,nqso
    ENDIF

    !    IF (.NOT. diag_errors) THEN
    !        DEALLOCATE( invcovmat)
    !    END IF

    end FUNCTION QSO_alpha_beta_like

    FUNCTION qso_LnLike(this, CMB, Theory, DataParams)
    Class(QSOLikelihood) :: this
    Class(CMBParams) CMB
    Class(TCosmoTheoryPredictions), target :: Theory
    real(mcp) DataParams(:)
    ! norm_alpha, norm_beta are the positions of alpha/beta in norm
    REAL(mcp) :: qso_LnLike
    real(dl) grid_best, zhel, zcmb, alpha, beta
    real(dl) estimated_scriptm 
    integer grid_i, i

    qso_LnLike = logZero

    !Make sure we're ready to actually do this
    IF (.NOT. qso_read) THEN
        STOP 'QSO data not read in; must be by this point'
    ENDIF
    IF (.NOT. qso_prepped ) THEN
        STOP 'qso data not prepped; run qso_prep'
    ENDIF

    !Get the luminosity distances.  CAMB doen't understand the
    ! difference between cmb and heliocentric frame redshifts.
    ! Camb gives us the angular diameter distance
    ! D(zcmb)/(1+zcmb) we want (1+zhel)*D(zcmb)
    !These come out in Mpc
    DO i=1,nqso
        zhel = qsodata(i)%zhel
        zcmb = qsodata(i)%zcmb
        lumdists(i) = 5.0* LOG10( (1.0+zhel)*(1.0+zcmb) * this%Calculator%AngularDiameterDistance(zcmb) )
    ENDDO

    !Handle QSO with absolute distances
    IF ( has_absdist ) THEN
        DO i=1,nabsdist
            lumdists( qsoabsdist(i)%index ) = 5.0*LOG10( qsoabsdist(i)%dl )
        ENDDO
    ENDIF
    if (QSO_marginalize) then
        !$OMP PARALLEL DO DEFAULT(SHARED),SCHEDULE(STATIC), PRIVATE(alpha,beta, grid_i)
        do grid_i = 1, QSO_int_points
            alpha = alpha_grid(grid_i)
            beta=beta_grid(grid_i)
            QSO_marge_grid(grid_i) = QSO_alpha_beta_like(alpha, beta, lumdists)
        end do

        grid_best = minval(QSO_marge_grid,mask=QSO_marge_grid/=logZero)
        qso_LnLike =  grid_best - log(sum(exp(-QSO_marge_grid + grid_best),  &
            mask=QSO_marge_grid/=logZero)*QSO_step_width_alpha*QSO_step_width_beta)
        IF (Feedback > 1) THEN
            WRITE(*,'(" QSO best logLike ",F7.2,", marge logLike: ",F7.2," for ",I5," QSO")') grid_best, qso_LnLike,nqso
        end if
    else
!        alpha=DataParams(1)   This if you want write k parameter
        estimated_scriptm=DataParams(1)
        beta=DataParams(2)

        qso_LnLike=QSO_alpha_beta_like(alpha, beta, lumdists)
    end if

    END FUNCTION qso_LnLike

    END MODULE QSO
