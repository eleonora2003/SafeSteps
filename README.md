
# 📝 SafeSteps – Varna navigacija ponoči
---

SafeSteps je mobilna aplikacija, razvita v Flutterju, namenjena izboljšanju varnosti navigacije ponoči. Integrira Google Maps za storitve, ki temeljijo na lokaciji, in Firebase za avtentikacijo uporabnikov ter shranjevanje podatkov. Aplikacija uporabnikom omogoča ogled in ocenjevanje varnosti ulic, vizualizacijo varnih poti na podlagi ocen uporabnikov ter pošiljanje emergency sporočil s svojo lokacijo.



## 🚀 Funkcionalnosti
---

### 1. 🔐 Google Prijava: 
- Varna avtentikacija uporabnikov s Firebase Authentication in Google Sign-In.
### 2. 🗺️ Interaktivni Google Maps: 
- Prikaz trenutne lokacije uporabnika in omogoča interakcijo z zemljevidom
### 3. 🌟 Ocenjevanje varnosti ulic: 
- Uporabniki lahko ocenijo lokacije od 1 do 10 in dodajo opcijske komentarje, ki se shranijo v Firebase Firestore v zbirki street_ratings.
### 4. 🆘 Emergency SOS: 
- Pošlje e-poštno sporočilo s trenutno lokacijo uporabnika na vnaprej določen e-poštni naslov za emergency pomoč.
### 5. 🎚️ Filtri: 
- Filtriraj oznake na zemljevidu, da prikaže vse, varne ali nevarne lokacije glede na povprečne ocene.
### 6. 🔄 Preklop vrste zemljevida: 
- Preklopi med običajnim in satelitskim pogledom.
### 7. 📖 Legenda: 
- Prikaže legendo, ki razlaga barvno označevanje oznak in segmentov poti.
### 8. 📋 Pogled vseh ocen: 
- Pojdi na ločen zaslon za ogled vseh ocen ulic.
### 9. 👤 Moje ocene:
- Pojdi na ločen zaslon za ogled ocen in odaberi moje ocen.
### 10. 📉 Pie chart - prikaz statistike
- Pojdi na ločen zaslon za ogled statistiko varnosti
### 11. 🚗 Prikaz polylines glede promet
- Prikaz varnosti preko polylines s barvami, glede promet.
### 12. 💡 Prikaz polylines glede osvetljenost
- Prikaz varnosti preko polylines s barvami, glede osvetljenost. 
### 13. 👥 Prikaz polylines glede ocene uporabnika
- Prikaz varnosti preko polylines s barvami, glede ocene uporabnika.
### 14. ↔️ Izbira prikaz poti med vozilo in hoja
- Možnost prikaz poti med vozilo in pa hoja.


## 🛠️ Tehnološki sklad 
---
### 📂 Frontend
 - Flutter (3.7.2+)
 - Dart

### 📂 Backend
 - Firebase Authentication (Google Sign-in)
 - Firestore (shranjevanje ocen)
 - Google Maps API

### ☁️ Razvojna okolja
 - Visual Studio Code
 - Android Studio
 - Firebase Console  


## 📲 Namestitev
---
### 1. Predpogoji

- Flutter: Različica 3.7.2 ali novejša (kot je določeno v pubspec.yaml).
- Dart: Združljiv s Flutter SDK (^3.7.2).
- Android Studio: Uporabljen kot primarni IDE in emulator za razvoj za Android.
- Firebase Account: Za avtentikacijo in Firestore bazo podatkov.

### 2. Navodila za namestitev

- Kloniraj repozitorij:

  **git clone** https://github.com/eleonora2003/SafeSteps
  **cd safesteps**

### 3. Namesti odvisnosti:
- Zaženite naslednji ukaz za namestitev vseh zahtevanih paketov iz pubspec.yaml:
   **flutter clean**
   **flutter pub get** 

### 4. Nastavi Firebase:

- Ustvarite projekt v Firebase Console.
- Dodajte Android aplikacijo v vaš Firebase projekt in prenesite datoteko google-services.json.
- Postavite datoteko google-services.json v mapo android/app.
- Omogočite Google Sign-In in Firestore v Firebase Console.

### 5. Nastavi Android Studio:

- Odprite projekt v Android Studiu.
- Prepričajte se, da je konfiguriran emulator ali fizična naprava.
- Namestite potrebne Android SDK-je. 

### 6. Zaženi aplikacijo

- S naslednji ukaz zaženite Flutter:

  **flutter run** 


### 👥 Avtorji in vloge 
---

 - Mila Nastoska - Emergency SOS, polylines - promet, prikaz ocene, search bar
 - Teodora Krunič - Google Sign-in, ocena lokacije, pie chart, moje ocene, polylines - ocena
 - Eleonora Stankovska - Google Map prikaz, filtriranje, legenda, izris polylines, polylines - osvetljenost

## 📁 Struktura projekta
---
- 🎯 lib/main.dart: Vstopna točka aplikacije.
- 🗺️ lib/screens/map_screen.dart: Glavni vmesnik zemljevida z Google Maps, načrtovanjem poti in varnostnimi funkcijami.
- 🖥️ lib/screens/login_screen.dart: Prijavni zaslon s funkcijo Google Sign-In.
- 👤 lib/screens/auth_service.dart: Upravljanje Firebase avtentikacije z Google Sign-In.
- ⭐ lib/screens/all_ratings_screen.dart: Prikaz vseh ocen ulic (ni prikazano v priloženi kodi, vendar je omenjeno).
- 📍 lib/screens/maps.dart: Implementacija polylines logike.
- 🧭 lib/screens/directions_model.dart: Podatki o poti. 
- 🧭 lib/screens/directions_repository.dart: Komunikacija z Google Maps API, pridobivanje podatkov, obdelava polylines
- 🗝️ lib/screens/env.dart: API key
- 📊 lib/screens/ratings_pie_chart_screen.dart: Statistika varnosti lokacijah.
- 📄 pubspec.yaml: Vsebuje odvisnosti in konfiguracijo aplikacije.
- 🖼️ assets/icon/location.png: Ikona aplikacije.


