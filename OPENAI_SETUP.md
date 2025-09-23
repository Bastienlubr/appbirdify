# 🔑 Configuration OpenAI pour l'enrichissement des fiches

## 🎯 Obtenir votre clé API OpenAI

1. Allez sur https://platform.openai.com/api-keys
2. Connectez-vous ou créez un compte
3. Cliquez "Create new secret key"  
4. Copiez la clé (format: `sk-proj-...`)

## ⚙️ Méthodes de configuration

### **1. Fichier .env (Recommandée) ✅**

Créez un fichier `.env` dans la racine du projet :

```bash
# Configuration OpenAI
OPENAI_API_KEY=sk-proj-votre_vraie_clé_ici
```

**Avantages:**
- ✅ Sécurisé (fichier ignoré par git)
- ✅ Automatiquement chargé par le script
- ✅ Réutilisable pour tous les scripts

### **2. Variable d'environnement PowerShell**

**Pour une session:**
```powershell
$env:OPENAI_API_KEY = "sk-proj-votre_clé"
node scripts/fiches/enrichir_hybride_wikipedia_ia.mjs --start=263 --end=263 --apply
```

**Permanent (utilisateur actuel):**
```powershell
[Environment]::SetEnvironmentVariable("OPENAI_API_KEY", "sk-proj-votre_clé", "User")
```

### **3. Variable d'environnement Système**

1. `Win + R` → `sysdm.cpl` → OK
2. Onglet "Avancé" → "Variables d'environnement"
3. "Nouveau" (utilisateur) → Nom: `OPENAI_API_KEY` → Valeur: votre clé
4. Redémarrer le terminal

## 🚀 Test de votre configuration

```bash
# Test de la clé
node -e "console.log('Clé détectée:', process.env.OPENAI_API_KEY ? '✅ OUI' : '❌ NON')"

# Enrichissement avec IA
node scripts/fiches/enrichir_hybride_wikipedia_ia.mjs --start=263 --end=263 --apply --verbose
```

## 🔍 Vérifications

| Méthode | Commande de test |
|---------|------------------|
| Fichier .env | `node -e "require('dotenv').config(); console.log(process.env.OPENAI_API_KEY)"` |
| Variable PowerShell | `$env:OPENAI_API_KEY` |
| Variable système | `echo $env:OPENAI_API_KEY` |

## 🛠️ Dépannage

**❌ "Variable OPENAI_API_KEY requise"**
- Vérifiez que la clé est bien définie
- Redémarrez le terminal après modification

**❌ "Erreur API IA: 401"**
- Clé invalide ou expirée
- Vérifiez les quotas sur https://platform.openai.com/usage

**❌ "Erreur API IA: 429"**  
- Limite de taux dépassée
- Attendez ou augmentez le délai dans le script

## 🎯 Recommandation

**Utilisez la méthode 1 (fichier .env)** :

1. Créez `.env` dans la racine
2. Ajoutez `OPENAI_API_KEY=votre_clé`
3. Le script chargera automatiquement la clé
4. Sécurisé et pratique ! ✅
