#!/usr/bin/env node
/**
 * Apply FR dashboard translations from cache + manual overrides (no external API).
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const LOCALE_DIR = path.join(ROOT, 'app/javascript/dashboard/i18n/locale');
const CACHE_PATH = path.join(__dirname, 'fr-translation-cache.json');
const OVERRIDES_PATH = path.join(__dirname, 'fr-manual-overrides.json');

const FILES = [
  'integrations.json',
  'inboxMgmt.json',
  'settings.json',
  'conversation.json',
  'contact.json',
  'generalSettings.json',
  'helpCenter.json',
  'bulkActions.json',
  'components.json',
  'automation.json',
  'macros.json',
  'labelsMgmt.json',
  'agentMgmt.json',
  'inbox.json',
];

const MANUAL_EN_TO_FR = {
  Shopify: 'Shopify',
  Captain: 'Captain',
  Copilot: 'Copilot',
  Webhook: 'Webhook',
  Slack: 'Slack',
  Linear: 'Linear',
  Notion: 'Notion',
  Actions: 'Actions',
  Done: 'Terminé',
  Secret: 'Secret',
  Cancel: 'Annuler',
  General: 'Général',
  Behavior: 'Comportement',
  Account: 'Compte',
  Controls: 'Contrôles',
  'Danger zone': 'Zone de danger',
  'Upgrade now': 'Passer à la version supérieure',
  'Try these prompts': 'Essayez ces suggestions',
  'Create a new assistant': 'Créer un assistant',
  Assistants: 'Assistants',
  'Edit Assistant': "Modifier l'assistant",
  'Delete Assistant': "Supprimer l'assistant",
  'View connected inboxes': 'Voir les boîtes de réception connectées',
  'No assistants available': 'Aucun assistant disponible',
  'Learn more about integrations': 'En savoir plus sur les intégrations',
  'Learn more about webhooks': 'En savoir plus sur les webhooks',
  'Fetching integrations': 'Récupération des intégrations',
  'Search integrations...': 'Rechercher des intégrations...',
  'No integrations found matching your search':
    'Aucune intégration ne correspond à votre recherche',
  'Inbox updated': 'Boîte de réception mise à jour',
  'Profile Picture': 'Photo de profil',
  'Font size': 'Taille de la police',
  Smaller: 'Plus petit',
  Small: 'Petit',
  Large: 'Grand',
  Larger: 'Plus grand',
  'Extra Large': 'Très grand',
  'Preferred Language': 'Langue préférée',
  'Use account default': 'Utiliser la langue du compte',
  Security: 'Sécurité',
  Reset: 'Réinitialiser',
  'Are you sure?': 'Êtes-vous sûr ?',
  'Click again to confirm': 'Cliquez à nouveau pour confirmer',
  'Play sound': 'Jouer le son',
  'Switch account': 'Changer de compte',
  'Contact support': 'Contacter le support',
  'Profile settings': 'Paramètres du profil',
  'Keyboard shortcuts': 'Raccourcis clavier',
  'Change appearance': "Modifier l'apparence",
  'Read documentation': 'Lire la documentation',
  Changelog: 'Journal des modifications',
  'Log out': 'Se déconnecter',
  'My Inbox': 'Ma boîte de réception',
  Conversations: 'Conversations',
  Contacts: 'Contacts',
  Companies: 'Entreprises',
  Notifications: 'Notifications',
  Macros: 'Macros',
  'Search...': 'Rechercher...',
  'There are no assistants available in your account.':
    "Aucun assistant n'est disponible sur votre compte.",
  'Are you sure to delete the assistant?':
    'Êtes-vous sûr de vouloir supprimer cet assistant ?',
  "Chatwoot integrates with multiple tools and services to improve your team's efficiency. Explore the list below to configure your favorite apps.":
    "Chatwoot s'intègre à de nombreux outils et services pour améliorer l'efficacité de votre équipe. Explorez la liste ci-dessous pour configurer vos applications préférées.",
  'Captain is not enabled on your account.':
    "Captain n'est pas activé sur votre compte.",
  'Click here to configure': 'Cliquez ici pour configurer',
  'Loading Captain Console...': 'Chargement de la console Captain...',
  'Failed to load Captain Console. Please refresh and try again.':
    'Échec du chargement de la console Captain. Veuillez actualiser et réessayer.',
  'Please reach out to your administrator for the upgrade.':
    'Veuillez contacter votre administrateur pour la mise à niveau.',
  'You can change or cancel your plan anytime':
    'Vous pouvez modifier ou annuler votre forfait à tout moment',
  'Customize the look and feel of your Chatwoot dashboard.':
    "Personnalisez l'apparence de votre tableau de bord Chatwoot.",
  'Delete Shopify Integration': "Supprimer l'intégration Shopify",
  'Are you sure you want to delete the Shopify integration?':
    "Êtes-vous sûr de vouloir supprimer l'intégration Shopify ?",
  'Connect Shopify Store': 'Connecter la boutique Shopify',
  'Store URL': 'URL de la boutique',
  'Connect Store': 'Connecter la boutique',
};

const PATH_OVERRIDES = {
  'integrations.json:CAPTAIN.ASSISTANTS.SETTINGS.TABS.GENERAL': 'Général',
  'integrations.json:CAPTAIN.ASSISTANTS.SETTINGS.TABS.BEHAVIOR': 'Comportement',
  'integrations.json:CAPTAIN.ASSISTANTS.SETTINGS.TABS.ACCOUNT': 'Compte',
  'integrations.json:CAPTAIN.ASSISTANTS.SETTINGS.TABS.CONTROLS': 'Contrôles',
  'integrations.json:CAPTAIN.ASSISTANTS.SETTINGS.TABS.DANGER': 'Zone de danger',
  'integrations.json:INTEGRATION_SETTINGS.WEBHOOK.FORM.SUBSCRIPTIONS.EVENTS.INBOX_UPDATED':
    'Boîte de réception mise à jour',
  'inboxMgmt.json:INBOX_MGMT.ADD.AUTH.CHANNEL.WAPI.TITLE': 'WhatsApp (WAPI)',
  'inboxMgmt.json:INBOX_MGMT.ADD.AUTH.CHANNEL.WAPI.DESCRIPTION':
    'Connectez votre propre WhatsApp via WAPI, sans compte Meta Business API.',
  'inboxMgmt.json:INBOX_MGMT.TABS.CALLS': 'Appels',
  'inboxMgmt.json:INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.ENABLING_CALLING':
    'Activation des appels en cours...',
  'inboxMgmt.json:INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.CALLING_ENABLE_FAILED':
    "Échec de l'activation des appels WhatsApp.",
  'inboxMgmt.json:INBOX_MGMT.ADD.AUTH.CHANNEL.WHATSAPP_CALL.TITLE':
    'Appels WhatsApp',
  'inboxMgmt.json:INBOX_MGMT.ADD.AUTH.CHANNEL.WHATSAPP_CALL.DESCRIPTION':
    'Recevez et passez des appels WhatsApp directement depuis Chatwoot.',
  'inboxMgmt.json:INBOX_MGMT.WHATSAPP_CALLING.ENABLE.LABEL':
    'Activer les appels WhatsApp',
  'inboxMgmt.json:INBOX_MGMT.WHATSAPP_CALLING.ENABLE.DESCRIPTION':
    'Permettez aux clients de vous appeler via WhatsApp depuis cette boîte de réception.',
  'inboxMgmt.json:INBOX_MGMT.WHATSAPP_CALLING.ENABLE_FAILED':
    "Échec de l'activation des appels WhatsApp.",
  'inboxMgmt.json:INBOX_MGMT.WHATSAPP_CALLING.PHONE_NUMBER.LABEL':
    'Numéro de téléphone',
  'inboxMgmt.json:INBOX_MGMT.WHATSAPP_CALLING.PHONE_NUMBER.HELP_TEXT':
    'Numéro WhatsApp utilisé pour les appels entrants et sortants.',
  'inboxMgmt.json:INBOX_MGMT.WHATSAPP_CALLING.HOW_IT_WORKS.LABEL':
    'Comment ça fonctionne',
  'inboxMgmt.json:INBOX_MGMT.WHATSAPP_CALLING.HOW_IT_WORKS.DESCRIPTION':
    "Les clients peuvent demander l'autorisation de vous appeler via WhatsApp. Une fois acceptée, vous pouvez les rappeler depuis Chatwoot.",
  'inboxMgmt.json:INBOX_MGMT.WHATSAPP_CALLING.PERMISSION_REQUEST_BODY.LABEL':
    "Message de demande d'autorisation",
  'inboxMgmt.json:INBOX_MGMT.WHATSAPP_CALLING.PERMISSION_REQUEST_BODY.HELP_TEXT':
    "Message envoyé au client pour demander l'autorisation de l'appeler.",
  'inboxMgmt.json:INBOX_MGMT.WHATSAPP_CALLING.PERMISSION_REQUEST_BODY.PLACEHOLDER':
    'Souhaitez-vous que nous vous appelions pour vous aider ?',
  'inboxMgmt.json:INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_CALLING_ENABLED.LABEL':
    'Appels WhatsApp activés',
  'inboxMgmt.json:INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_CALLING_ENABLED.DESCRIPTION':
    'Les appels WhatsApp sont activés pour cette boîte de réception.',
};

function loadJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function saveJson(filePath, data) {
  fs.writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`, 'utf8');
}

function isValidTranslation(text) {
  if (!text || typeof text !== 'string') return false;
  if (text.includes('MYMEMORY WARNING')) return false;
  if (text.includes('QUERY LENGTH LIMIT EXCEEDED')) return false;
  if (text.startsWith('MYMEMORY WARNING')) return false;
  return true;
}

function loadCache() {
  if (!fs.existsSync(CACHE_PATH)) return {};
  const cache = loadJson(CACHE_PATH);
  return Object.fromEntries(
    Object.entries(cache).filter(([, value]) => isValidTranslation(value))
  );
}

function loadOverrides() {
  if (!fs.existsSync(OVERRIDES_PATH)) return {};
  return loadJson(OVERRIDES_PATH);
}

function translate(enText, pathKey, cache, overrides) {
  if (PATH_OVERRIDES[pathKey]) return PATH_OVERRIDES[pathKey];
  if (overrides[enText]) return overrides[enText];
  if (MANUAL_EN_TO_FR[enText]) return MANUAL_EN_TO_FR[enText];
  if (cache[enText] && isValidTranslation(cache[enText])) return cache[enText];
  return enText;
}

function deepSync(
  enNode,
  frNode,
  cache,
  overrides,
  stats,
  pathPrefix = '',
  fileName = ''
) {
  if (typeof enNode === 'string') {
    const pathKey = `${fileName}:${pathPrefix}`;
    if (frNode === undefined || frNode === enNode) {
      const translated = translate(enNode, pathKey, cache, overrides);
      if (translated !== enNode) stats.translated += 1;
      return translated;
    }
    stats.preserved += 1;
    return frNode;
  }

  if (Array.isArray(enNode)) return enNode;

  const result = frNode && typeof frNode === 'object' ? { ...frNode } : {};
  for (const key of Object.keys(enNode)) {
    const childPath = pathPrefix ? `${pathPrefix}.${key}` : key;
    result[key] = deepSync(
      enNode[key],
      frNode?.[key],
      cache,
      overrides,
      stats,
      childPath,
      fileName
    );
  }
  return result;
}

const cache = loadCache();
const overrides = loadOverrides();
const summary = [];

for (const file of FILES) {
  const enPath = path.join(LOCALE_DIR, 'en', file);
  const frPath = path.join(LOCALE_DIR, 'fr', file);
  const en = loadJson(enPath);
  const fr = loadJson(frPath);
  const stats = { translated: 0, preserved: 0 };

  const updated = deepSync(en, fr, cache, overrides, stats, '', file);
  saveJson(frPath, updated);
  summary.push({ file, ...stats });
  console.log(
    `${file}: translated ${stats.translated}, preserved ${stats.preserved}`
  );
}

console.table(summary);
