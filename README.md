
# SafeSteps – Varna navigacija ponoči
---

SafeSteps je mobilna aplikacija, razvita v Flutterju, namenjena izboljšanju varnosti navigacije ponoči. Integrira Google Maps za storitve, ki temeljijo na lokaciji, in Firebase za avtentikacijo uporabnikov ter shranjevanje podatkov. Aplikacija uporabnikom omogoča ogled in ocenjevanje varnosti ulic, vizualizacijo varnih poti na podlagi ocen uporabnikov ter pošiljanje emergency sporočil s svojo lokacijo.




## Funkcionalnosti
---

### 1. Google Prijava: 
- Varna avtentikacija uporabnikov s Firebase Authentication in Google Sign-In.
### 2. Interaktivni Google Maps: 
- Prikaz trenutne lokacije uporabnika in omogoča interakcijo z zemljevidom
### 3. Ocenjevanje varnosti ulic: 
- Uporabniki lahko ocenijo lokacije od 1 do 10 in dodajo opcijske komentarje, ki se shranijo v Firebase Firestore v zbirki street_ratings.
### 4. Emergency SOS: 
- Pošlje e-poštno sporočilo s trenutno lokacijo uporabnika na vnaprej določen e-poštni naslov za emergency pomoč.
### 5. Filtri: 
- Filtriraj oznake na zemljevidu, da prikaže vse, varne ali nevarne lokacije glede na povprečne ocene.
### 6. Preklop vrste zemljevida: 
- Preklopi med običajnim in satelitskim pogledom.
### 7. Povzetek ocen: 
- Prikaz povprečne ocene vseh lokacij in razčlenitev varnih, zmernih in tveganih segmentov poti.
### 8. Legenda: 
- Prikaže legendo, ki razlaga barvno označevanje oznak in segmentov poti.
### 9. Pogled vseh ocen: 
- Pojdi na ločen zaslon za ogled vseh ocen ulic.




## Namestitev
---
### 1. Predpogoj

- Flutter: Različica 3.7.2 ali novejša (kot je določeno v pubspec.yaml).
- Dart: Združljiv s Flutter SDK (^3.7.2).
- Android Studio: Uporabljen kot primarni IDE in emulator za razvoj za Android.
- Firebase Account: Za avtentikacijo in Firestore bazo podatkov.

### 2. Navodila za namestitev

- Kloniraj repozitorij:
**git clone <repository-url>**
**cd safesteps**

### 3. Namesti odvisnosti:
- Zaženite naslednji ukaz za namestitev vseh zahtevanih paketov iz pubspec.yaml:
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




## Zagon aplikacije
---

### 1. Odpri v Android Studiu:

- Zaženite Android Studio .
- Prepričajte se, da je izbran emulator ali priklopljena naprava.


### 2. Zgradi in zaženi:

- Kliknite gumb Run v Android Studiu ali uporabite ukaz:
  **flutter run**
- Aplikacija se bo zgradila in zažela na emulatorju/napravi.



## Struktura projekta
---
- lib/main.dart: Vstopna točka aplikacije.
- lib/map_screen.dart: Glavni vmesnik zemljevida z Google Maps, načrtovanjem poti in varnostnimi funkcijami.
- lib/login_screen.dart: Prijavni zaslon s funkcijo Google Sign-In.
- lib/auth_service.dart: Upravljanje Firebase avtentikacije z Google Sign-In.
- lib/all_ratings_screen.dart: Prikaz vseh ocen ulic (ni prikazano v priloženi kodi, vendar je omenjeno).
- pubspec.yaml: Vsebuje odvisnosti in konfiguracijo aplikacije.
- assets/icon/location.png: Ikona aplikacije za Android in iOS.


