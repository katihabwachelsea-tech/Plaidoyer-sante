# Guide de test E2E — Plaidoyer Santé

Guide manuel pour tester **tout le cycle** Patient + Médecin, de l’inscription jusqu’au dossier médical.

Idéal : **2 téléphones** (ou 1 émulateur + 1 appareil).  
Possible aussi : un seul appareil, en se déconnectant / reconnectant entre les rôles.

---

## 0. Prérequis

### Backend Laravel

- Serveur démarré : `php artisan serve --host=0.0.0.0 --port=8000`
- Migrations à jour : `php artisan migrate`
- Au moins **un service de consultation** en base (nom + prix), sinon le patient ne peut pas réserver.

### Flutter

- URL API dans `lib/config/app_config.dart` :
  - émulateur Android : `10.0.2.2`
  - appareil réel : **IP LAN de ton PC** (actuellement `192.168.30.31`)
- L’app est en **mode production** (`AppDataMode.enableProductionMode()` dans `main.dart`) : les données viennent du vrai backend, pas des mocks.
- Lancer : `flutter run`

### Comptes de test à créer

| Rôle | Email exemple | Mot de passe | Notes |
|------|----------------|--------------|--------|
| Médecin | `dr.test@plaidoyer.bi` | `Test1234` | min. 8 caractères à l’inscription |
| Patient | `patient.test@plaidoyer.bi` | `Test1234` | min. 8 caractères à l’inscription |

Connexion : mot de passe min. **6** caractères.  
Inscription : mot de passe min. **8** caractères.

---

## 1. Cycle métier (à retenir)

```
Médecin crée un créneau
        ↓
Patient réserve → statut En_attente (créneau bloqué, invisible au médecin)
        ↓
Patient paie (Ecocash / Lumicash simulé) → statut Confirme
        ↓
Médecin voit le RDV → ouvre Consultation
        ↓
Médecin enregistre diagnostic + ordonnance → statut Termine
        ↓
Patient voit le compte-rendu dans Dossier
```

| Statut API | Côté patient | Côté médecin |
|------------|--------------|--------------|
| `En_attente` | Badge **À payer** | **Invisible** |
| `Confirme` | Badge **Confirmé** | Visible, bouton Consulter |
| `Termine` | Badge **Terminé** | Disparaît des RDV confirmés |
| `Annule` | Badge **Annulé** | Disparaît |

---

## 2. Validations d’entrée (avant les parcours complets)

À faire une fois, écran Connexion puis Inscription.

### Connexion

1. Ouvrir l’app → écran **Connexion**.
2. Laisser email / mot de passe vides → **Se connecter** → erreurs « Email requis » / « Mot de passe requis ».
3. Email `pas-un-email` → « Adresse email invalide ».
4. Mot de passe de 4 caractères → « Au moins 6 caractères requis ».
5. Bons identifiants inexistants → SnackBar d’erreur (identifiants incorrects ou serveur injoignable).
6. Icône œil : affiche / masque le mot de passe.

### Inscription

1. **Créer un compte**.
2. Email invalide, nom < 3 caractères, mot de passe < 8, confirmation différente → messages d’erreur.
3. **Annuler** → retour login.

---

# PARTIE A — Médecin (préparer l’offre)

Faire **avant** le patient, sinon il n’y a ni médecin ni créneau.

## A1. Inscription médecin + onboarding

1. Login → **Créer un compte**.
2. Remplir :
   - Email : `dr.test@plaidoyer.bi`
   - Téléphone : `79 111 111` (optionnel)
   - Mot de passe + confirmation : `Test1234`
   - Photo : optionnelle (galerie)
   - Nom : `Dr. Jean Nard`
   - Rôle : **Médecin** (défaut actuel)
3. **Créer le compte**.
4. Écran **Complétez votre profil** (pas de bouton retour).
5. Remplir **tous** les champs (tous requis) :
   - Spécialité : `Cardiologue`
   - Licence : `LIC-2026-001`
   - Hôpital : `CHU de Bujumbura`
   - Disponibilité : `Lundi-Vendredi 9h-17h`
   - Biographie : `Cardiologue, 10 ans d'expérience.`
6. **Finaliser mon inscription**.
7. **Attendu** : snackbar succès → barre du bas **Accueil / RDV / Créneaux / Profil**.
8. Accueil : « Bonjour, … », cartes Patients / À venir / Créneaux, message « Les rendez-vous payés du jour apparaîtront ici » si aucun RDV payé.

## A2. Profil médecin

1. Onglet **Profil**.
2. Vérifier nom, spécialité, hôpital, téléphone, bio, disponibilités.
3. Modifier la bio → **Enregistrer les modifications** → snackbar « Profil mis à jour ».
4. Revenir sur Profil : la modification est toujours là (API, pas seulement local).

## A3. Créer des créneaux (obligatoire pour réserver)

1. Onglet **Créneaux**.
2. Titre **Mes disponibilités**.
3. Date vide → **Ajouter un créneau** → snackbar « Choisissez une date ».
4. Icône calendrier → date **aujourd’hui** (ou demain).
5. Début `09:00`, Fin `10:00` → **Ajouter un créneau**.
6. **Attendu** : snackbar « Créneau ajouté », ligne avec date, `09:00 — 10:00`, badge **Libre**.
7. Ajouter au moins 2 autres créneaux (ex. `10:00–11:00`, `14:00–15:00`) **le même jour** pour tester le choix de slots.
8. Tirer pour rafraîchir : les créneaux restent.

> Le patient ne peut réserver que sur une date où le médecin a des créneaux **libres**.

## A4. RDV médecin (état vide)

1. Onglet **RDV**.
2. **Attendu** : « Aucun rendez-vous confirmé. Les RDV apparaissent ici uniquement après paiement. »

Ne pas se déconnecter tout de suite si tu as 2 appareils. Sinon : **Profil → Déconnexion** → login.

---

# PARTIE B — Patient (inscription + découverte)

## B1. Inscription patient + onboarding

1. **Créer un compte**.
2. Remplir :
   - Email : `patient.test@plaidoyer.bi`
   - Téléphone : `79 222 222`
   - Mot de passe : `Test1234`
   - Nom : `Marie Ndikumana`
   - Rôle : **Patient**
3. **Créer le compte**.
4. Onboarding santé :
   - Date de naissance : `15/05/1990` (format affiché `JJ/MM/AAAA`)
   - Groupe sanguin : `O+`
   - Maladie : `Hypertension` (optionnel)
   - Antécédents : `Diabète type 2 dans la famille` (optionnel)
5. **Finaliser mon inscription**.
6. **Attendu** : barre **Accueil / RDV / Dossier / Profil**.
7. Accueil : « Bonjour, Marie », barre de recherche, « Aucun rendez-vous à venir » si pas encore de RDV.

## B2. Accueil + liste des médecins

1. La liste **Médecins** affiche `Dr. Jean Nard`, spécialité `Cardiologue`, hôpital `CHU de Bujumbura`.
2. Recherche `cardio` → le médecin reste. Recherche `zzzz` → « Aucun médecin trouvé ». Croix : liste complète.
3. **Voir tous** → **Trouver un médecin**.
4. Filtrer par spécialité `Cardiologue` → le médecin apparaît.
5. Revenir à l’accueil (retour).

## B3. Profil patient

1. Onglet **Profil**.
2. Nom, email, téléphone, groupe sanguin, motif, antécédents.
3. Changer le téléphone → **Enregistrer** → snackbar « Profil enregistré ».
4. Ne pas se déconnecter avant d’avoir fini le cycle RDV.

## B4. Dossier (état vide)

1. Onglet **Dossier**.
2. **Attendu** : « Aucune consultation enregistrée… »

---

# PARTIE C — Flow principal croisé (le plus important)

Deux appareils : Patient connecté + Médecin connecté.  
Un appareil : rester patient jusqu’au paiement, puis reconnecter le médecin.

## C1. Patient réserve

1. Accueil → carte du médecin → **Prendre RDV**  
   (ou **Trouver un médecin** → **Nouveau rendez-vous** / FAB **Prendre RDV**).
2. Écran **Prendre rendez-vous** : nom, spécialité, hôpital.
3. Choisir la **date** où tu as créé les créneaux.
4. **Attendu** : chips des heures libres (ex. `09:00`).  
   Autre date sans créneau → « Aucun créneau libre ce jour. »
5. Choisir un créneau, ex. `09:00`.
6. Choisir un **type de consultation** (tarif en FBu). Sans service : « Tarifs indisponibles » + Réessayer.
7. Motif : `Douleurs thoraciques depuis 3 jours`.
8. **Envoyer la demande**.
9. Bottom sheet : médecin, date/heure, motif, tarif, texte « Le rendez-vous reste en attente jusqu’au paiement. »
10. **Envoyer la demande** (confirmation).
11. **Attendu** : ouverture automatique de **Paiement Mobile Money**.

### Sans payer tout de suite (optionnel)

- Retour avant de payer.
- Accueil : RDV avec badge **À payer** + **Payer maintenant**.
- Onglet **RDV** : même RDV, boutons **Payer** et **Annuler**.
- **Côté médecin (important)** : le RDV **n’apparaît pas**. Pull-to-refresh. Compteur « aujourd’hui » inchangé.

## C2. Patient paie

1. Écran paiement (après réservation ou via **Payer**).
2. Vérifier médecin, service, date, montant.
3. Choisir **Ecocash** ou **Lumicash** (« Simulation — aucun débit réel »).
4. Numéro prérempli (téléphone du compte). Si < 8 chiffres → « Entrez un numéro de téléphone valide ».
5. **Payer Ecocash · XXX FBu**.
6. **Attendu** : reçu **Paiement confirmé**, référence, moyen, téléphone, médecin, prestation.
7. **Terminer**.
8. Accueil / **RDV** : badge **Confirmé**, plus de bouton Payer.
9. La facture affiche le montant **Payé** et éventuellement le `transaction_id`.

## C3. Médecin voit le RDV payé

1. Appareil médecin (ou reconnexion `dr.test@plaidoyer.bi`).
2. Accueil → pull-to-refresh.
3. **Attendu** :
   - « 1 rendez-vous confirmé(s) aujourd’hui » (si RDV aujourd’hui)
   - cartes Patients / À venir mises à jour
   - bloc **Aujourd’hui** : nom du patient + motif + **Consulter**
4. Onglet **RDV** :
   - patient, motif, date/heure, badge **Confirmé**
   - référence de paiement si présente
   - boutons **Annuler** et **Consulter**
5. Onglet **Créneaux** : le créneau `09:00–10:00` est **Occupé** (plus Libre).

## C4. Médecin consulte (termine le RDV)

1. Accueil **Consulter** ou RDV **Consulter**.
2. Formulaire : patient, motif, chip **Payé**.
3. Enregistrer sans diagnostic → « Diagnostic requis ».
4. Sans ordonnance → « Ordonnance requise ».
5. Optionnel : **Aide IA Gemini** → suggestions (ou message d’indisponibilité si pas de clé).
6. Remplir :
   - Diagnostic : `Suspicion d'angor d'effort. ECG et bilan lipidique recommandés.`
   - Ordonnance : `AAS 100 mg 1x/j. Repos relatif. Contrôle dans 7 jours.`
   - Notes : `Patient inquiet, explications données.`
7. **Terminer la consultation**.
8. **Attendu** : snackbar « Consultation enregistrée — RDV terminé », retour accueil/RDV.
9. Le RDV **disparaît** de la liste confirmée (statut `Termine`).
10. Dashboard : consultations +1 si l’API le compte.

## C5. Patient voit le dossier

1. Revenir sur le compte patient.
2. Onglet **Dossier** → pull-to-refresh.
3. **Attendu** : carte avec
   - nom du médecin
   - service + date
   - **Diagnostic** (texte saisi)
   - **Ordonnance**
   - notes / conseils si présents
   - ligne facture **Payée** + référence
4. Onglet **RDV** : le même RDV en **Terminé**, plus de Payer / Annuler.

---

# PARTIE D — Flows secondaires Patient

## D1. Annuler un RDV avant paiement

1. Réserver un **nouveau** créneau (ne pas payer).
2. **RDV** → **Annuler** → dialogue « Le créneau sera libéré… »
3. **Non** → rien ne change.
4. **Annuler le RDV** → snackbar « Rendez-vous annulé ».
5. Badge **Annulé**, plus de Payer.
6. Côté médecin : le créneau redevient **Libre**.
7. Un autre patient (ou le même) peut reprendre ce créneau.

## D2. Annuler un RDV déjà payé (patient)

1. Réserver + payer un autre créneau.
2. **RDV** → **Annuler** (possible si futur + `Confirme`).
3. **Attendu** : RDV annulé côté patient ; disparaît chez le médecin ; créneau libéré.

## D3. Annuler côté médecin

1. Patient réserve + paie.
2. Médecin → **RDV** → **Annuler** → confirmer.
3. Snackbar « Rendez-vous annulé ».
4. Patient : statut **Annulé** après refresh.

## D4. Double réservation / créneau pris

1. Patient A réserve `10:00` (même sans payer, le créneau est bloqué).
2. Patient B (ou même compte, autre essai) sur la même date : `10:00` ne doit plus être libre.
3. Si l’API refuse quand même : snackbar d’erreur de réservation.

## D5. Recherche et navigation

1. Accueil **Trouver un médecin** / **Nouveau rendez-vous**.
2. FAB **Prendre RDV** sur l’onglet RDV.
3. Après réservation, l’accueil affiche jusqu’à **3** prochains RDV (`En_attente` ou `Confirme`, dates futures).
4. Pull-to-refresh accueil : médecins + RDV se rechargent.

---

# PARTIE E — Flows secondaires Médecin

## E1. Dashboard

1. Pull-to-refresh.
2. Cartes rapides **RDV aujourd’hui / Agenda / Consultations** → page RDV.
3. **Mes rendez-vous** en bas → même page.
4. Si API down : bandeau orange « Mode hors-ligne ou API indisponible ».

## E2. Créneaux limites

1. Date passée : le date picker commence à **aujourd’hui**.
2. Créneau déjà existant (même date/heures) : erreur API ou doublon — noter le comportement réel.
3. Liste vide : « Aucun créneau sur les 30 prochains jours ».

## E3. Déconnexion / session

1. Médecin **Profil → Déconnexion** → login.
2. Patient **Profil → Se déconnecter** → login.
3. Mauvais rôle : un patient ne doit jamais voir **Créneaux** médecin.
4. Relancer l’app après login : aujourd’hui `home` est toujours `LoginPage` (pas `AuthCheck`). La session n’est donc **pas** restaurée au cold start — à noter pour la soutenance. Après login, la navigation rôle est correcte (`patient` → PatientNavigation, `medecin` → MedecinNavigation).

---

# PARTIE F — Cas d’erreur / robustesse

| # | Action | Attendu |
|---|--------|---------|
| F1 | Backend éteint, login | SnackBar « Erreur de connexion au serveur » |
| F2 | Mauvais mot de passe | Message identifiants incorrects |
| F3 | Email déjà inscrit | Erreur d’inscription (email unique) |
| F4 | Réserver sans date/créneau | « Choisissez une date et un créneau » |
| F5 | Réserver sans service | « Choisissez un type de consultation… » |
| F6 | Réserver sans motif | « Précisez le motif de la consultation » |
| F7 | Payer avec 3 chiffres | « Entrez un numéro de téléphone valide » |
| F8 | Token expiré pendant une action | Erreur / « Session expirée » |
| F9 | Pull-to-refresh partout (accueil, RDV, dossier, créneaux) | Rechargement sans crash |
| F10 | Rotation écran / clavier | Formulaire reste utilisable |

---

# PARTIE G — Scénario soutenance (15–20 min)

Ordre recommandé devant un jury :

1. **Inscrire le médecin** + onboarding + **2 créneaux** le jour J.
2. **Inscrire le patient** + onboarding.
3. Accueil patient : montrer le médecin, rechercher, **Prendre RDV**.
4. Confirmer la demande → **ne pas payer tout de suite**.
5. Passer sur le téléphone médecin : **le RDV n’est pas là** (règle métier).
6. Patient : **Payer** Ecocash → reçu → **Terminer**.
7. Médecin : refresh → RDV **Confirmé** + créneau **Occupé**.
8. **Consulter** → diagnostic + ordonnance → **Terminer la consultation**.
9. Patient → **Dossier** : compte-rendu + facture payée.
10. (Bonus) Annuler un 2ᵉ RDV et montrer le créneau libéré.

---

## Checklist finale

### Médecin

- [ ] Inscription + onboarding
- [ ] Accueil / dashboard
- [ ] Création de créneaux
- [ ] RDV invisible tant que non payé
- [ ] RDV visible après paiement
- [ ] Consultation (validation + enregistrement)
- [ ] Créneau Occupé puis libéré si annulation
- [ ] Édition profil + déconnexion

### Patient

- [ ] Inscription + onboarding
- [ ] Accueil, recherche, liste médecins
- [ ] Réservation (date, slot, service, motif)
- [ ] Paiement simulé + reçu
- [ ] Liste RDV (À payer / Confirmé / Terminé / Annulé)
- [ ] Annulation
- [ ] Dossier après consultation
- [ ] Édition profil + déconnexion

### Croisé

- [ ] En_attente → invisible médecin
- [ ] Confirme → visible médecin
- [ ] Termine → dossier patient
- [ ] Annule → créneau libre

---

## Données de démo (si tu veux précharger en Tinker)

```php
$medecin = \App\Models\Medecin::first();
$patient = \App\Models\User::where('role', 'patient')->first();

\App\Models\RendezVous::create([
    'medecin_id' => $medecin->id,
    'patient_user_id' => $patient->id,
    'motif' => 'Suivi oncologie',
    'statut' => 'Confirme',
    'date_heure' => now()->addHours(2),
    'montant' => 5000,
    'payment_ref' => 'PAY-TEST-001',
]);
```

À n’utiliser que si tu veux **sauter** réservation + paiement et tester directement la consultation médecin.
