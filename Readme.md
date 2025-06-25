##  Descrizione del Campione QSO

Il campione QSO originale utilizzato per applicazioni **cosmologiche** si basa sulla compilazione di **Lusso et al. (2020)**. Questa versione include solo sorgenti con una determinazione **fotometrica** del **flusso UV** e applica un **taglio in redshift** a **z > 0.7**, come descritto nello stesso articolo.

I **dati** sono disponibili pubblicamente presso il **CDS** tramite **ftp anonimo** all'indirizzo:  
[ftp://130.79.128.5](ftp://130.79.128.5)  
oppure via web:  
[http://cdsarc.u-strasbg.fr/viz-bin/cat/J/A+A/642/A150](http://cdsarc.u-strasbg.fr/viz-bin/cat/J/A+A/642/A150)

---

## I.  **Selezione e Calibrazione**

Questa sezione descrive la procedura applicata al campione QSO originale per costruire la **funzione di verosimiglianza (likelihood)**. I seguenti passi sono seguiti:

- Fissiamo i parametri **pendenza (γ)** e **intercetta (β)** della relazione **Risaliti–Lusso** (vedi Eq. 1 di **Benetti et al., 2025**).
- Utilizzando questi valori fissati, calcoliamo le **distanze di luminosità**.
- Deriviamo quindi i **moduli di distanza**, che sono le **quantità effettive** implementate nella **likelihood MCMC**.

###  Calibrazione

La calibrazione procede come segue:

- **γ** e **β** sono ottenuti mediante un **fit congiunto** del campione QSO e del campione **Pantheon SNe Ia**, utilizzando un **polinomio logaritmico ortogonale di quinto ordine**, come descritto in **Bargiacchi et al. 2021**.  
  In particolare, la combinazione di **QSOs** e **SNe Ia** in questo fit impone una **calibrazione dei QSOs** con le **Pantheon SNe Ia**.

- Le **distanze di luminosità** sono poi calcolate usando la **Eq. (1)** in **Benetti et al. 2025**, sostituendo i valori fissati di **γ** e **β**.

- I **moduli di distanza** e le relative **incertezze** sono infine ottenuti da queste distanze. Questi valori rappresentano l'**osservabile principale QSO** usato come **input** nei moduli **MCMC likelihood**.

I **dati QSO** e la relativa **matrice di covarianza** sono forniti nella cartella **QSO Data/**.  
Nella tabella, il **modulo di distanza** e la sua **incertezza** sono etichettati come **mb** e **dmb**, rispettivamente.

---

## II.  **Uso**

La **likelihood** è stata implementata per l'utilizzo con **Cobaya** e **CosmoMC**.  
Istruzioni dettagliate e file di configurazione di esempio sono forniti nella cartella **MCMC**.

---

## III.  **Supporto**

Se riscontri problemi o hai bisogno di assistenza con i codici, contatta:

- **Micol Benetti** – m.benetti@ssmeridionale.it  
- **Giada Bargiacchi** – gbargiacchi@lnf.infn.it
