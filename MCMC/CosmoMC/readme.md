# QSO Likelihood Integration in CosmoMC

This repository provides an implementation of the QSO (quasar) likelihood for use within **CosmoMC**, adapted from existing supernova modules. It enables inclusion of QSO data in cosmological parameter inference analyses.

---

## 1. Prerequisites

Ensure your **CosmoMC** installation is functional before applying the following changes.

---

## 2. Source Code Modifications

### 2.1 Edit `supernovae.f90`

In `CosmoMC/source/supernovae.f90`:

- Add the following line at the beginning of the file:
  ```fortran
  use QSO
  ```

- Register the QSO likelihood:
  ```fortran
  call QSOLikelihood_Add(LikeList, Ini)
  ```

- Comment out the restriction preventing simultaneous datasets:
  ```fortran
  ! if (LikeList%Count > count+1) call MpiStop('SNLikelihood_Add: more than one - datasets not independent')
  ```

### 2.2 Add the QSO Module

Copy `supernovae_QSO.f90` to the `CosmoMC/source/` directory.

---

## 3. Update Makefile

In `CosmoMC/source/Makefile`:

- Around line **180**, update the `SUPERNOVAE` object list:
  ```makefile
  SUPERNOVAE = $(OUTPUT_DIR)/supernovae_Union2.o $(OUTPUT_DIR)/supernovae_SNLS.o \
               $(OUTPUT_DIR)/supernovae_JLA.o $(OUTPUT_DIR)/supernovae_QSO.o
  ```

- Around line **270**, add the compilation dependency for QSO:
  ```makefile
  $(OUTPUT_DIR)/supernovae_QSO.o: $(OUTPUT_DIR)/Likelihood_Cosmology.o
  ```

---

## 4. Data and Configuration

Move the following folders into the corresponding **CosmoMC** directories:

- `batch3/`  
- `data/`

These folders contain the necessary QSO likelihood configuration files and datasets.

---

## 5. Running the Likelihood

To include QSO data in your analysis, add this line to your primary `.ini` configuration file:

```ini
DEFAULT(batch3/QSO.ini)
```

Compile CosmoMC with:
```bash
make
```

---

## Support

For further information or assistance, contact:

- [m.benetti@ssmeridionale.it](mailto:m.benetti@ssmeridionale.it)
- [gbargiacchi@lnf.infn.it](mailto:gbargiacchi@lnf.infn.it)

