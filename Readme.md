# 🌌 Quasar Likelihood for Cosmological MCMC Codes

This repository provides a patch to include the **quasar likelihood (QSO)** in cosmological parameter estimation codes such as [`Cobaya`](https://github.com/CobayaSampler/cobaya) and [`CosmoMC`](https://cosmologist.info/cosmomc/).  
It relies on the quasar sample released and validated in:

- **E. Lusso et al. (2020)**  
  *Quasars as standard candles III: Validation of a new sample for cosmological studies*,  
  **A&A 642 (2020) A150**  
  [arXiv:2008.08586](https://arxiv.org/abs/2008.08586) · [DOI:10.1051/0004-6361/202038899](https://doi.org/10.1051/0004-6361/202038899)

This work builds upon the foundational method introduced in:

- **G. Risaliti and E. Lusso (2019)**  
  *Cosmological constraints from the Hubble diagram of quasars at high redshifts*,  
  **Nature Astronomy 3 (2019) 272–277**  
  [arXiv:1811.02590](https://arxiv.org/abs/1811.02590) · [DOI:10.1038/s41550-018-0657-z](https://doi.org/10.1038/s41550-018-0657-z)

For usage instructions, see [`README_usage.md`](./README_usage.md).  
If you use this likelihood or the data in this repository, please cite:

> **Benetti, Bargiacchi, Risaliti, Lusso, Signorini, Capozziello (2025)**  
> *Quasar Cosmology II: Joint analyses with the Cosmic Microwave Background*  
> **DARK-D-24-01031R1**  
> [arXiv: ](https://arxiv.org)
---

---# 📊 QSO Sample: Original Data

The data are publicly available at the [CDS](http://cdsarc.u-strasbg.fr/viz-bin/cat/J/A+A/642/A150) via anonymous FTP:

* ftp\://130.79.128.5

---

## I. 🧪 Selection and Calibration

This section outlines the procedure applied to the original QSO sample in order to build the likelihood. The following steps are performed:

1. **Fix the slope ($\gamma$) and intercept ($\beta$)** parameters of the **Risaliti–Lusso relation** (see Eq. 1 in Benetti et al. 2025).
2. Using these fixed values, **compute the luminosity distances**.
3. **Derive the distance moduli**, which are the actual quantities implemented in the MCMC likelihood.

### Calibration Procedure

* $\gamma$ and $\beta$ are obtained by fitting both the **QSO sample** and the **Pantheon SNe Ia sample** using a **cosmographic orthogonal fifth-order logarithmic polynomial**, as described in **Bargiacchi et al. (2021)**.
* This joint fit calibrates the QSO data against the Pantheon sample.
* **Luminosity distances** are then calculated using Eq. (1) from Benetti et al. (2025), with the fixed $\gamma$ and $\beta$.
* **Distance moduli and their uncertainties** are computed from the derived luminosity distances. These are the primary QSO observables used as input to the MCMC likelihood.

The QSO data and the corresponding **covariance matrix** are provided in the `QSO_Data/` directory.

* In the data table, the **distance modulus** and its **uncertainty** are labeled as `mb` and `dmb`, respectively.

---

## II. ⚙️ Usage

The QSO likelihood has been implemented for use with both:

* [`Cobaya`](https://github.com/CobayaSampler/cobaya)
* [`CosmoMC`](https://cosmologist.info/cosmomc/)

Detailed instructions and example configuration files are available in the `MCMC/` directory.

---

## III. 🧑‍💻 Support

For issues, bug reports, or technical questions, please contact:

* **Micol Benetti** – [m.benetti@ssmeridionale.it](mailto:m.benetti@ssmeridionale.it)
* **Giada Bargiacchi** – [gbargiacchi@lnf.infn.it](mailto:gbargiacchi@lnf.infn.it)



## IV. 📚 Additional Relevant Literature

The following papers provide essential context, validation, and theoretical interpretation for the quasar standard candle method:

1. **Bargiacchi et al. (2022)**  
   *Quasar cosmology: Dark energy evolution and spatial curvature*  
   **MNRAS 515 (2022) 1795–1806**  
   [arXiv:2111.02420](https://arxiv.org/abs/2111.02420)

2. **Lusso, Risaliti, Nardini (2025)**  
   *Are quasars reliable standard candles?*  
   **A&A 697 (2025) A108**  
   [arXiv:2504.02040](https://arxiv.org/abs/2504.02040)

3. **Kammoun et al. (2025)**  
   *Explaining the UV–X-ray correlation in AGN via X-ray illumination of accretion discs*  
   **A&A 697 (2025) A55**  
   [arXiv:2503.20770](https://arxiv.org/abs/2503.20770)

4. **Trefoloni et al. (2024)**  
   *Quasars as standard candles VI: Spectroscopic validation of the cosmological sample*  
   **A&A 689 (2024) A109**  
   [arXiv:2404.07205](https://arxiv.org/abs/2404.07205)

5. **Signorini et al. (2024)**  
   *Building the high-redshift Hubble diagram with quasars*  
   [arXiv:2401.07909](https://arxiv.org/abs/2401.07909)

6. **Signorini et al. (2023)**  
   *Quasars as standard candles V: Accounting for the dispersion in the L<sub>X</sub>–L<sub>UV</sub> relation down to ≤ 0.06 dex*  
   **A&A 687 (2024) A32**  
   [arXiv:2312.08448](https://arxiv.org/abs/2312.08448)

7. **Signorini et al. (2023)**  
   *Quasars as standard candles IV: Analysis of X-ray and UV indicators of the disc–corona relation*  
   **A&A 676 (2023) A143**  
   [arXiv:2306.16438](https://arxiv.org/abs/2306.16438)

8. **Sacchi et al. (2022)**  
   *Quasars as high-redshift standard candles*  
   **A&A 663 (2022) L7**  
   [arXiv:2206.13528](https://arxiv.org/abs/2206.13528)

