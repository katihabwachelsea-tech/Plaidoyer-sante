# 📋 Guide Laravel - Endpoints API

## 🚀 Installation des Endpoints

J'ai créé 3 nouveaux contrôleurs et routes pour ton backend Laravel. Voici ce qu'il faut faire :

---

## 1️⃣ Copier les Contrôleurs

Crée ces fichiers dans ton projet Laravel :

### A. `app/Http/Controllers/Api/MedecinController.php`
```
📁 app
  📁 Http
    📁 Controllers
      📁 Api
        ✅ MedecinController.php  (à créer)
```

**Fonctionnalités :**
- `GET /api/medecins` → Liste tous les médecins
- `GET /api/medecins?specialite=Cardiologue` → Filtre par spécialité
- `GET /api/medecins?search=Jean` → Cherche par nom
- `POST /api/medecin/complete-profile` → Complète le profil médecin (onboarding)

### B. `app/Http/Controllers/Api/SpecialiteController.php`
```
📁 app/Http/Controllers/Api
  ✅ SpecialiteController.php  (à créer)
```

**Fonctionnalités :**
- `GET /api/specialites` → Récupère toutes les spécialités uniques

### C. `app/Http/Controllers/Api/PatientController.php`
```
📁 app/Http/Controllers/Api
  ✅ PatientController.php  (à créer)
```

**Fonctionnalités :**
- `POST /api/patient/complete-profile` → Complète le profil patient (onboarding)

---

## 2️⃣ Mettre à jour les Routes

Édite `routes/api.php` et ajoute :

```php
// Routes publiques
Route::get('/medecins', [MedecinController::class, 'index']);
Route::get('/medecins/{id}', [MedecinController::class, 'show']);
Route::get('/specialites', [SpecialiteController::class, 'index']);

// Routes protégées (authentification Sanctum requise)
Route::middleware('auth:sanctum')->group(function () {
    Route::post('/medecin/complete-profile', [MedecinController::class, 'completeProfile']);
    Route::post('/patient/complete-profile', [PatientController::class, 'completeProfile']);
});
```

---

## 3️⃣ Vérifier tes Modèles

Assure-toi que tu as :

### ✅ Model `Medecin` 
```php
// app/Models/Medecin.php
class Medecin extends Model {
    protected $fillable = [
        'user_id',
        'specialite',
        'licence',
        'hopital',
        'biographie',
        'disponibilite',
        'is_validated',
    ];

    public function user() {
        return $this->belongsTo(User::class);
    }
}
```

### ✅ Model `Patient`
```php
// app/Models/Patient.php
class Patient extends Model {
    protected $fillable = [
        'user_id',
        'date_naissance',
        'groupe_sanguin',
        'maladie',
        'antecedents',
    ];

    public function user() {
        return $this->belongsTo(User::class);
    }
}
```

### ✅ Model `User`
Doit avoir la colonne `is_profile_completed` (boolean, default false)

```php
// migration
Schema::create('users', function (Blueprint $table) {
    $table->id();
    $table->string('nom');
    $table->string('email')->unique();
    $table->string('password');
    $table->string('telephone')->nullable();
    $table->enum('role', ['patient', 'medecin'])->default('patient');
    $table->boolean('is_profile_completed')->default(false); // ← IMPORTANT
    $table->string('profileImageUrl')->nullable();
    $table->timestamps();
});
```

---

## 4️⃣ Tester les Endpoints

Une fois tout en place, teste avec Postman ou Hoppscotch :

```bash
# 1. Récupérer tous les médecins
GET http://localhost:8000/api/medecins

# 2. Filtrer par spécialité
GET http://localhost:8000/api/medecins?specialite=Cardiologue

# 3. Chercher par nom
GET http://localhost:8000/api/medecins?search=Jean

# 4. Récupérer les spécialités
GET http://localhost:8000/api/specialites

# 5. Compléter le profil médecin (besoin d'authentification)
POST http://localhost:8000/api/medecin/complete-profile
Headers:
  Authorization: Bearer {TOKEN}
  Content-Type: application/json
Body:
{
  "specialite": "Cardiologue",
  "licence": "LIC-2024-001",
  "hopital": "CHU de Bujumbura",
  "biographie": "Médecin expérimenté...",
  "disponibilite": "Lundi-Vendredi 9h-17h"
}

# 6. Compléter le profil patient (besoin d'authentification)
POST http://localhost:8000/api/patient/complete-profile
Headers:
  Authorization: Bearer {TOKEN}
  Content-Type: application/json
Body:
{
  "date_naissance": "1990-05-15",
  "groupe_sanguin": "O+",
  "maladie": "Hypertension",
  "antecedents": "Diabète type 2"
}
```

---

## 5️⃣ Commandes à exécuter

Dans ton projet Laravel :

```bash
# Recharger et nettoyer le cache
php artisan config:cache
php artisan route:cache

# Si tu as des migrations à appliquer
php artisan migrate
```

---

## ✅ Résumé

Une fois tout configuré, le Flutter peut :
1. ✅ Afficher la liste des médecins
2. ✅ Filtrer par spécialité
3. ✅ Chercher un médecin
4. ✅ Compléter le profil (onboarding) pour médecin et patient
5. ✅ L'app fonctionne end-to-end ! 🎉

---

**Questions ?**
- Si tu as une erreur, dis-moi le message d'erreur
- Si tu as besoin de modifier quelque chose, je peux adapter le code

