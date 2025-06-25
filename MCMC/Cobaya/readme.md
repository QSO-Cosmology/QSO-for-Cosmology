# QSO Likelihood Integration in Cobaya

This repository provides the implementation of a QSO (quasar) data likelihood in **Cobaya**, following the structure of the `Pantheon` supernova module. This setup allows cosmological analyses to include quasar data as standardizable candles.

---

## 1. Data Directory Setup

A dedicated directory was created to store the QSO data:

```
/home/your_account/cobaya-packages/code/data/qso_data
```

This directory includes the following files:

- `covmat_Quasar.txt`
- `full_long.dataset`
- `lcparam_full_long_zhel.txt`

---

## 2. Likelihood Folder Implementation

A new folder named `qso` was created inside:

```
/home/your_account/.conda/envs/cobaya-env/lib/python3.13/site-packages/cobaya/likelihoods/
```

This folder was adapted from the existing `sn/Pantheon` module and updated to support QSO data. The folder is included in this release under `likelihoods/qso` for clarity.

---

## 3. Base Class Modification

The file `sn.py` was duplicated and renamed `qso.py` in:

```
/home/your_account/.conda/envs/cobaya-env/lib/python3.13/site-packages/cobaya/likelihoods/base_classes/
```

Within `qso.py`, the absolute magnitude parameter `Mb` was replaced by a new parameter `k`:

```python
Mb = k
```

---

## 4. Initialization Update

In the same `base_classes` directory, the `__init__.py` file was modified to register the QSO class:

```python
from .qso import QSO
```

---

## 5. YAML Configuration Example

Below is an example of how to configure the QSO likelihood in a Cobaya `.yaml` file:

```yaml
likelihood:
  H0.riess2020Mb: null
  sn.pantheon:
    use_abs_mag: true
  qso.qso:
    use_abs_mag: true

params:
  k:
    prior:
      min: -20.0
      max: 20.0
    latex: k

# Optional MCMC settings
mcmc:
  # drag: true
```

---

## Notes

- If any issue arises during compilation or execution, ensure that all module paths are correct and properly referenced.
- The QSO module is designed to parallel the structure of the SN likelihood for maximum compatibility.

For questions or support, please contact:

- [m.benetti@ssmeridionale.it](mailto\:m.benetti@ssmeridionale.it)
- g.bargiacchi@[domain].it

