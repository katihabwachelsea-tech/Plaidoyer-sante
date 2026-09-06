# Module Médecin — Guide d'installation

## Backend Laravel

Dans votre projet Laravel complet, copiez les fichiers de `backend_laravel/` puis :

```bash
php artisan migrate
php artisan route:clear
```

### Endpoints créés

| Méthode | URL | Description |
|---------|-----|-------------|
| GET | `/api/medecin/appointments` | RDV **Confirme** uniquement |
| GET | `/api/medecin/appointments/today-count` | Nombre RDV aujourd'hui |
| POST | `/api/consultations` | Crée consultation + RDV → **Termine** |
| GET | `/api/medecin/profile` | Profil médecin |
| PUT | `/api/medecin/profile` | Mise à jour profil |
| GET | `/api/medecin/creneaux` | Liste créneaux |
| POST | `/api/medecin/creneaux` | Ajouter créneau |

### Logique métier RDV

- `En_attente` → réservation, créneau bloqué
- `Confirme` → **après paiement API** (seuls visibles par le médecin)
- `Termine` → après POST `/api/consultations`
- Pas de bouton Accepter/Refuser côté médecin

### Données de test (Tinker)

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

## Flutter

### Fichiers créés

```
lib/pages/medecin/
├── medecin_navigation.dart
├── medecin_home_page.dart
├── medecin_appointments_page.dart
├── consultation_form_page.dart
├── medecin_profile_page.dart
└── medecin_schedule_page.dart

lib/services/medecin_api_service.dart
lib/models/appointment.dart
```

### URL API

Modifiez `baseUrl` dans `medecin_api_service.dart` si besoin :
- Émulateur Android : `http://10.0.2.2:8000/api`
- Appareil réel : `http://VOTRE_IP:8000/api`

### Connexion

- Rôle `medecin` → `MedecinNavigation`
- Rôle `patient` → `PatientHomePage`
