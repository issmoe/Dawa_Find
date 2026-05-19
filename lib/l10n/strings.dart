// All UI strings for EN / FR / AR
// Usage: AppStrings.of(lang).someKey

class AppStrings {
  final String lang;
  const AppStrings._(this.lang);

  factory AppStrings.of(String lang) {
    switch (lang) {
      case 'FR': return const AppStrings._('FR');
      case 'AR': return const AppStrings._('AR');
      default:   return const AppStrings._('EN');
    }
  }

  bool get isRTL => lang == 'AR';

  // ── Find Screen ────────────────────────────────────────
  String get findTitle => _s('Find Your\nMedications', 'Trouvez Vos\nMédicaments', 'ابحث عن\nأدويتك');
  String get findSubtitle => _s(
    'Enter your prescription and find pharmacies with everything in stock',
    'Entrez votre ordonnance et trouvez les pharmacies avec tout en stock',
    'أدخل وصفتك الطبية وابحث عن الصيدليات التي تمتلك كل شيء في المخزون',
  );
  String get addMedHint   => _s('Add medication name...', 'Ajouter un médicament...', 'أضف اسم الدواء...');
  String get searchBtn    => _s('Search Pharmacies', 'Chercher des pharmacies', 'البحث عن الصيدليات');
  String get howItWorks   => _s('HOW IT WORKS', 'COMMENT ÇA MARCHE', 'كيف يعمل');
  String get step1        => _s('Enter each medication from your prescription', 'Entrez chaque médicament de votre ordonnance', 'أدخل كل دواء من وصفتك الطبية');
  String get step2        => _s('We check inventory across all pharmacies', 'Nous vérifions les stocks dans toutes les pharmacies', 'نتحقق من المخزون في جميع الصيدليات');
  String get step3        => _s('See which ones have everything you need', 'Voyez lesquelles ont tout ce dont vous avez besoin', 'تعرف على أي منها يملك كل ما تحتاجه');
  String get addMedEmpty  => _s('Please add at least one medication.', 'Veuillez ajouter au moins un médicament.', 'يرجى إضافة دواء واحد على الأقل.');
  String searching(int n) => _s('Searching for $n medication(s)…', 'Recherche de $n médicament(s)…', 'جارٍ البحث عن $n دواء...');

  // ── Donate Screen ──────────────────────────────────────
  String get donateTitle    => _s('Medication Donations', 'Dons de médicaments', 'التبرع بالأدوية');
  String get donateSubtitle => _s('Give unused medications to those in need', 'Donnez vos médicaments inutilisés à ceux qui en ont besoin', 'تبرع بأدويتك غير المستخدمة لمن يحتاجها');
  String get browse         => _s('Browse', 'Parcourir', 'تصفح');
  String get myDonations    => _s('My Donations', 'Mes dons', 'تبرعاتي');

  // ── Requests Screen ────────────────────────────────────
  String get requestsTitle    => _s('Donation Requests', 'Demandes de dons', 'طلبات التبرع');
  String get requestsSubtitle => _s('People seeking specific medications', 'Personnes cherchant des médicaments spécifiques', 'أشخاص يبحثون عن أدوية بعينها');
  String get myRequests       => _s('My Requests', 'Mes demandes', 'طلباتي');

  // ── Shared ─────────────────────────────────────────────
  String get signInRequired => _s('Sign in required', 'Connexion requise', 'تسجيل الدخول مطلوب');
  String get signInMsg      => _s(
    'You need a user account to view and manage your donations and requests. Tap the Pharmacies tab and choose "I\'m a User" to sign in.',
    'Vous avez besoin d\'un compte pour gérer vos dons et demandes. Appuyez sur l\'onglet Pharmacies et choisissez "Je suis un utilisateur".',
    'تحتاج إلى حساب مستخدم لعرض تبرعاتك وطلباتك وإدارتها. انقر على تبويب الصيدليات واختر "أنا مستخدم" لتسجيل الدخول.',
  );

  // ── Bottom Nav ─────────────────────────────────────────
  String get navFind        => _s('Find', 'Chercher', 'بحث');
  String get navDonate      => _s('Donate', 'Donner', 'تبرع');
  String get navRequests    => _s('Requests', 'Demandes', 'طلبات');
  String get navPharmacies  => _s('Pharmacies', 'Pharmacies', 'صيدليات');

  // ── Pharmacies Screen ──────────────────────────────────
  String get welcomeTitle     => _s('Welcome', 'Bienvenue', 'مرحباً');
  String get welcomeSubtitle  => _s('Choose how you want to use the pharmacies section', 'Choisissez comment vous souhaitez utiliser la section pharmacies', 'اختر كيف تريد استخدام قسم الصيدليات');
  String get imUser           => _s("I'm a User", "Je suis un utilisateur", "أنا مستخدم");
  String get imUserSub        => _s('Browse pharmacies and their information', 'Parcourez les pharmacies et leurs informations', 'تصفح الصيدليات ومعلوماتها');
  String get imPharmacy       => _s("I'm a Pharmacy", "Je suis une pharmacie", "أنا صيدلية");
  String get imPharmacySub    => _s('Sign in to manage your medication stock', 'Connectez-vous pour gérer votre stock de médicaments', 'سجّل الدخول لإدارة مخزون أدويتك');

  // helper
  String _s(String en, String fr, String ar) {
    if (lang == 'FR') return fr;
    if (lang == 'AR') return ar;
    return en;
  }
}
