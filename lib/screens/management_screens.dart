import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/stat_card.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  int _view = 0;

  @override
  Widget build(BuildContext context) {
    final isStudents = _view == 0;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(30, 24, 30, 30),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AppTopBar(
              title: 'Suivi des présences',
              subtitle: isStudents ? 'Suivez l’assiduité individuelle des étudiants' : 'Consultez la fiche de suivi de chaque cours',
              actions: [
                OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download_outlined, size: 16), label: const Text('Exporter')),
                const SizedBox(width: 8),
                ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.add, size: 16), label: Text(isStudents ? 'Marquer une présence' : 'Nouvelle séance')),
              ],
            ),
            const SizedBox(height: 20),
            _AttendanceViewSwitcher(selected: _view, onChanged: (value) => setState(() => _view = value)),
            const SizedBox(height: 20),
            if (isStudents) const _StudentAttendanceView() else const _CourseFollowUpView(),
          ]),
        ),
      ),
    );
  }
}

class _AttendanceViewSwitcher extends StatelessWidget {
  final int selected; final ValueChanged<int> onChanged;
  const _AttendanceViewSwitcher({required this.selected, required this.onChanged});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.inputBorder)),
    child: Row(children: [
      _ViewChoice(index: 0, selected: selected, icon: Icons.people_alt_outlined, label: 'Présence des étudiants', onTap: () => onChanged(0)),
      _ViewChoice(index: 1, selected: selected, icon: Icons.assignment_outlined, label: 'Fiche de suivi des cours', onTap: () => onChanged(1)),
    ]),
  );
}

class _ViewChoice extends StatelessWidget {
  final int index, selected; final IconData icon; final String label; final VoidCallback onTap;
  const _ViewChoice({required this.index, required this.selected, required this.icon, required this.label, required this.onTap});
  @override Widget build(BuildContext context) => Expanded(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(9), child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16), decoration: BoxDecoration(color: selected == index ? AppColors.primaryBlue : Colors.transparent, borderRadius: BorderRadius.circular(9)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 18, color: selected == index ? Colors.white : AppColors.textSecondary), const SizedBox(width: 9), Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected == index ? Colors.white : AppColors.textSecondary))]))));
}

class _StudentAttendanceView extends StatelessWidget {
  const _StudentAttendanceView();
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const _AttendanceKpis(items: [_Metric('Étudiants suivis', '128', 'Groupe G2-Info', Icons.people_alt_outlined), _Metric('Taux de présence', '87,5%', '+3,2% ce mois', Icons.donut_large_outlined), _Metric('Présences validées', '1 024', 'sur 1 170 séances', Icons.check_circle_outline), _Metric('À surveiller', '08', '3 absences ou plus', Icons.warning_amber_outlined)]),
    const SizedBox(height: 18), const _FilterRow(labels: ['Programme : Informatique', 'Niveau : Licence 2', 'Groupe : G2-Info', 'Période : Mai 2024']),
    const SizedBox(height: 18),
    _DataTableCard(title: 'Assiduité des étudiants', columns: const ['#', 'Étudiant', 'N° étudiant', 'Présences', 'Absences', 'Retards', 'Taux', 'Statut', 'Actions'], rows: const [
      ['01', 'Ahmed Ben Ahmad', '20230001', '24', '2', '1', '92,3%', 'Régulier', '•••'], ['02', 'Nora El Amine', '20230002', '23', '3', '0', '88,5%', 'Régulier', '•••'], ['03', 'Julien Bernard', '20230003', '20', '6', '2', '76,9%', 'À surveiller', '•••'], ['04', 'Anina Fofana', '20230004', '25', '1', '0', '96,2%', 'Régulier', '•••'], ['05', 'Yassine Zahra', '20230005', '18', '8', '3', '69,2%', 'Alerte', '•••'],
    ]),
  ]);
}

class _CourseFollowUpView extends StatefulWidget {
  const _CourseFollowUpView();
  @override State<_CourseFollowUpView> createState() => _CourseFollowUpViewState();
}

class _CourseFollowUpViewState extends State<_CourseFollowUpView> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  String _sessionType = 'CM';
  DateTime? _arrivalDate;
  DateTime? _departureDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override void dispose() { _contentController.dispose(); super.dispose(); }

  Future<void> _pickDate({required bool arrival}) async {
    final value = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2035), initialDate: DateTime.now());
    if (value != null) setState(() { if (arrival) { _arrivalDate = value; } else { _departureDate = value; } });
  }

  Future<void> _pickTime({required bool start}) async {
    final value = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (value != null) setState(() { if (start) { _startTime = value; } else { _endTime = value; } });
  }

  String _date(DateTime? value) => value == null ? 'Sélectionner une date' : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  String _time(TimeOfDay? value) => value == null ? 'Sélectionner l’heure' : value.format(context);

  void _submit() {
    if (!_formKey.currentState!.validate() || _arrivalDate == null || _departureDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez compléter les dates et horaires obligatoires.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La fiche de suivi est prête à être soumise.')));
  }

  @override Widget build(BuildContext context) => Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _Panel(title: 'Fiche de suivi du professeur', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Informations de la séance', style: AppTextStyles.h2), const SizedBox(height: 18),
      Row(children: [Expanded(child: _FollowUpTextField(label: 'Titre du cours', hint: 'Ex. Algorithmique')), const SizedBox(width: 16), Expanded(child: _FollowUpTextField(label: 'Séance', hint: 'Ex. Séance 05'))]),
      const SizedBox(height: 16),
      Row(children: [Expanded(child: _FollowUpPicker(label: 'Date d’arrivée du professeur', value: _date(_arrivalDate), icon: Icons.calendar_today_outlined, onTap: () => _pickDate(arrival: true))), const SizedBox(width: 16), Expanded(child: _FollowUpPicker(label: 'Date de départ du professeur', value: _date(_departureDate), icon: Icons.calendar_today_outlined, onTap: () => _pickDate(arrival: false)))]),
      const SizedBox(height: 16),
      Row(children: [Expanded(child: _FollowUpPicker(label: 'Heure de début du cours', value: _time(_startTime), icon: Icons.schedule_outlined, onTap: () => _pickTime(start: true))), const SizedBox(width: 16), Expanded(child: _FollowUpPicker(label: 'Heure de fin du cours', value: _time(_endTime), icon: Icons.schedule_outlined, onTap: () => _pickTime(start: false)))]),
      const SizedBox(height: 20),
      const Text('Type de séance', style: AppTextStyles.label), const SizedBox(height: 9),
      Row(children: ['CM', 'TD', 'TP'].map((type) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 10), child: ChoiceChip(label: Text(type), selected: _sessionType == type, onSelected: (_) => setState(() => _sessionType = type), selectedColor: AppColors.primaryBlue, labelStyle: TextStyle(color: _sessionType == type ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w700), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: _sessionType == type ? AppColors.primaryBlue : AppColors.inputBorder)))))).toList()),
      const SizedBox(height: 22),
      _FollowUpTextField(label: 'Contenu du cours', hint: 'Saisissez le contenu traité, les objectifs et les remarques de la séance…', maxLines: 7, controller: _contentController),
    ])),
    const SizedBox(height: 18),
    _Panel(title: 'Validation de la fiche', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _SignatureBox(label: 'Signature du professeur', icon: Icons.draw_outlined)), const SizedBox(width: 16), Expanded(child: _SignatureBox(label: 'Signature du délégué', icon: Icons.border_color_outlined))]),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [OutlinedButton(onPressed: () => _formKey.currentState?.reset(), child: const Text('Réinitialiser')), const SizedBox(width: 12), ElevatedButton.icon(onPressed: _submit, icon: const Icon(Icons.send_outlined, size: 17), label: const Text('Soumettre la fiche'))]),
    ])),
  ]));
}

class _FollowUpTextField extends StatelessWidget { final String label, hint; final int maxLines; final TextEditingController? controller; const _FollowUpTextField({required this.label, required this.hint, this.maxLines = 1, this.controller}); @override Widget build(BuildContext context) => TextFormField(controller: controller, maxLines: maxLines, validator: (value) => value == null || value.trim().isEmpty ? 'Champ obligatoire' : null, decoration: InputDecoration(labelText: label, hintText: hint, alignLabelWithHint: maxLines > 1)); }
class _FollowUpPicker extends StatelessWidget { final String label, value; final IconData icon; final VoidCallback onTap; const _FollowUpPicker({required this.label, required this.value, required this.icon, required this.onTap}); @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: InputDecorator(decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 19)), child: Text(value, style: TextStyle(color: value.startsWith('Sélectionner') ? AppColors.textMuted : AppColors.textPrimary)))); }
class _SignatureBox extends StatelessWidget { final String label; final IconData icon; const _SignatureBox({required this.label, required this.icon}); @override Widget build(BuildContext context) => Container(height: 116, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.inputBorder)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: AppTextStyles.label), const Spacer(), Center(child: Icon(icon, size: 27, color: AppColors.textMuted)), const Spacer(), const Center(child: Text('Cliquer pour signer', style: TextStyle(color: AppColors.textMuted, fontSize: 12)))])); }

class _AttendanceKpis extends StatelessWidget { final List<_Metric> items; const _AttendanceKpis({required this.items}); @override Widget build(BuildContext context) => Wrap(spacing: 14, runSpacing: 14, children: items.map((m) => SizedBox(width: 210, child: StatCard(label: m.label, value: m.value, delta: m.detail, icon: m.icon, iconBackground: AppColors.primaryBlue))).toList()); }
class _FollowUpLegend extends StatelessWidget { const _FollowUpLegend(); @override Widget build(BuildContext context) => Row(children: [const Icon(Icons.info_outline, size: 17, color: AppColors.textMuted), const SizedBox(width: 8), Text('La fiche de suivi regroupe les informations administratives et pédagogiques de la séance.', style: AppTextStyles.body)]); }



class ConferencesScreen extends StatefulWidget { const ConferencesScreen({super.key}); @override State<ConferencesScreen> createState() => _ConferencesScreenState(); }
class _ConferencesScreenState extends State<ConferencesScreen> {
  bool showDialogBox = false;
  @override Widget build(BuildContext context) => _ManagementPage(
    title: 'Gestion des conférences', subtitle: 'Organisez vos visioconférences et séances en ligne', action: 'Nouvelle conférence', icon: Icons.add,
    onAction: () => setState(() => showDialogBox = true),
    stats: const [_Metric('Conférences actives', '2', 'En direct', Icons.videocam_outlined), _Metric('Planifiées', '5', 'À venir', Icons.event_outlined), _Metric('Participants actuels', '28', 'Connectés', Icons.people_alt_outlined), _Metric('Total participants max', '156', 'Capacité totale', Icons.groups_outlined)],
    child: _DataTableCard(title: 'Mes conférences', columns: const ['Titre', 'Organisateur', 'Date / Heure', 'Mode', 'Participants', 'Durée', 'Statut', 'Actions'], rows: const [
      ['Algorithmique — CM / Groupe 1–2', 'Pr. El-Khaled', 'Maintenant', 'En ligne', '41/50', '1h24', 'EN DIRECT', 'Démarrer'],
      ['Cours IA Avancée / Groupe L3', 'Pr. Makled', 'Aujourd’hui 14h', 'En ligne', '0/35', '—', 'Planifiée', 'Détails'],
      ['Séminaire Projet Groupe P2 Beta', 'Dr. Dubois', '15/05/2024', 'LAN', '0/20', '55min', 'Planifiée', 'Détails'],
      ['Tutorat BDD', 'Dr. Benkacem', 'Passé', 'En ligne', '18/20', '56min', 'Terminée', 'Rapport'],
    ]),
  );
}

class CommunicationsScreen extends StatelessWidget { const CommunicationsScreen({super.key}); @override Widget build(BuildContext context) => _ManagementPage(title: 'Communications', subtitle: 'Notifications, annonces et messages de la communauté', action: 'Nouvelle annonce', icon: Icons.add, stats: const [], child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _AnnouncementList()), const SizedBox(width: 18), SizedBox(width: 300, child: _NoticeCard())])); }
class _AnnouncementList extends StatelessWidget { @override Widget build(BuildContext context) => _Panel(title: 'Dernières communications', child: Column(children: const [_MessageRow(icon: Icons.campaign_outlined, title: 'Réunion pédagogique', text: 'La réunion est prévue vendredi à 10h.', time: 'Il y a 20 min'), _MessageRow(icon: Icons.info_outline, title: 'Mise à jour de la plateforme', text: 'Une maintenance est planifiée ce week-end.', time: 'Hier'), _MessageRow(icon: Icons.school_outlined, title: 'Inscriptions aux examens', text: 'Les inscriptions sont ouvertes jusqu’au 25 mai.', time: 'Hier'), _MessageRow(icon: Icons.event_outlined, title: 'Nouveau calendrier', text: 'Le calendrier du semestre est disponible.', time: '12 mai')])); }
class _NoticeCard extends StatelessWidget { @override Widget build(BuildContext context) => _Panel(title: 'Rédiger une annonce', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('Titre', style: AppTextStyles.label), const SizedBox(height: 8), const TextField(decoration: InputDecoration(hintText: 'Objet de l’annonce')), const SizedBox(height: 14), const Text('Message', style: AppTextStyles.label), const SizedBox(height: 8), const TextField(maxLines: 5, decoration: InputDecoration(hintText: 'Votre message…')), const SizedBox(height: 16), ElevatedButton(onPressed: null, child: Text('Publier l’annonce'))])); }
class _MessageRow extends StatelessWidget { final IconData icon; final String title, text, time; const _MessageRow({required this.icon, required this.title, required this.text, required this.time}); @override Widget build(BuildContext context) => ListTile(contentPadding: const EdgeInsets.symmetric(vertical: 8), leading: CircleAvatar(backgroundColor: AppColors.inputFill, child: Icon(icon, color: AppColors.primaryBlue)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(text), trailing: Text(time, style: AppTextStyles.body.copyWith(fontSize: 11))); }

class StatisticsScreen extends StatelessWidget { const StatisticsScreen({super.key}); @override Widget build(BuildContext context) => _ManagementPage(title: 'Tableau de bord Statistiques', subtitle: 'Analysez les performances académiques de votre établissement', action: 'Exporter PDF', icon: Icons.download_outlined, stats: const [_Metric('Taux de présence moyen', '78,4%', '+3,2%', Icons.event_available_outlined), _Metric('Taux de réussite', '86,7%', '+1,5%', Icons.trending_up), _Metric('Moyenne générale', '4,2/5', 'sur barème 5', Icons.star_border), _Metric('Satisfaction étudiants', '82,1%', '+5,1%', Icons.sentiment_satisfied_alt_outlined)], child: Column(children: [Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _ChartPanel(title: 'Évolution du taux de présence', values: const [72, 74, 78, 77])), const SizedBox(width: 16), Expanded(child: _ChartPanel(title: 'Répartition par matière', values: const [92, 85, 80, 78, 74, 68]))]), const SizedBox(height: 16), Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _ChartPanel(title: 'Réussite des étudiants', values: const [82, 12, 6])), const SizedBox(width: 16), Expanded(child: _DataTableCard(title: 'Top 5 UE par présence', columns: const ['UE', 'Taux', 'Tendance'], rows: const [['INFO201', '92,3%', '+4,1%'], ['INFO202', '88,7%', '+3,2%'], ['RESE301', '84,5%', '+2,7%'], ['MATH101', '79,8%', '+1,9%'], ['INFO204', '76,6%', '+1,3%']]))]) ])); }

class SettingsScreen extends StatelessWidget { const SettingsScreen({super.key}); @override Widget build(BuildContext context) => _ManagementPage(title: 'Paramètres', subtitle: 'Configurez votre espace UniFlow', stats: const [], child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _Panel(title: 'Préférences générales', child: Column(children: const [_SettingRow(title: 'Notifications système', subtitle: 'Recevoir les alertes importantes', value: true), _SettingRow(title: 'Mode hors connexion', subtitle: 'Conserver une copie locale des données', value: true), _SettingRow(title: 'Synchronisation automatique', subtitle: 'Mettre à jour les données après reconnexion', value: true)]))), const SizedBox(width: 18), const Expanded(child: _Panel(title: 'Compte administrateur', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Administrateur', style: TextStyle(fontWeight: FontWeight.w700)), SizedBox(height: 6), Text('admin@uniflow.edu', style: AppTextStyles.body), SizedBox(height: 20), Text('Les données seront connectées à Appwrite dans la prochaine intégration.', style: AppTextStyles.body)]))) ])); }
class _SettingRow extends StatelessWidget { final String title, subtitle; final bool value; const _SettingRow({required this.title, required this.subtitle, required this.value}); @override Widget build(BuildContext context) => SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(subtitle), value: value, onChanged: null); }

class _ManagementPage extends StatelessWidget { final String title, subtitle; final String? action; final IconData? icon; final VoidCallback? onAction; final List<_Metric> stats; final Widget child; const _ManagementPage({required this.title, required this.subtitle, required this.stats, required this.child, this.action, this.icon, this.onAction}); @override Widget build(BuildContext context) => Scaffold(backgroundColor: AppColors.background, body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(30, 24, 30, 30), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [AppTopBar(title: title, subtitle: subtitle, actions: [if (action != null) ElevatedButton.icon(onPressed: onAction, icon: Icon(icon ?? Icons.arrow_forward, size: 16), label: Text(action!))]), if (stats.isNotEmpty) ...[const SizedBox(height: 22), Wrap(spacing: 14, runSpacing: 14, children: stats.map((m) => SizedBox(width: 210, child: StatCard(label: m.label, value: m.value, delta: m.detail, icon: m.icon, iconBackground: AppColors.primaryBlue))).toList())], const SizedBox(height: 22), child])))); }
class _Metric { final String label, value, detail; final IconData icon; const _Metric(this.label, this.value, this.detail, this.icon); }
class _FilterRow extends StatelessWidget {
  final List<String> labels;
  const _FilterRow({required this.labels});
  @override Widget build(BuildContext context) => Wrap(
    spacing: 10, runSpacing: 10,
    children: labels.map((e) => SizedBox(width: 220, child: DropdownButtonFormField<String>(value: e, items: [DropdownMenuItem<String>(value: e, child: Text(e, overflow: TextOverflow.ellipsis))], onChanged: null, decoration: const InputDecoration()))).toList(),
  );
}
class _Panel extends StatelessWidget { final String title; final Widget child; const _Panel({required this.title, required this.child}); @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.inputBorder)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title, style: AppTextStyles.h2.copyWith(fontSize: 16)), const SizedBox(height: 14), child])); }
class _DataTableCard extends StatelessWidget { final String title; final List<String> columns; final List<List<String>> rows; const _DataTableCard({required this.title, required this.columns, required this.rows}); @override Widget build(BuildContext context) => _Panel(title: title, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 12), dataTextStyle: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary), columns: columns.map((c) => DataColumn(label: Text(c))).toList(), rows: rows.map((r) => DataRow(cells: r.map((v) => DataCell(Text(v))).toList())).toList()))); }
class _ChartPanel extends StatelessWidget { final String title; final List<int> values; const _ChartPanel({required this.title, required this.values}); @override Widget build(BuildContext context) => _Panel(title: title, child: SizedBox(height: 180, child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: values.asMap().entries.map((e) => Column(mainAxisAlignment: MainAxisAlignment.end, children: [Text('${e.value}%'), const SizedBox(height: 6), Container(width: 30, height: e.value * 1.25, decoration: BoxDecoration(color: e.key.isEven ? AppColors.primaryBlue : AppColors.teal, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))), const SizedBox(height: 8), Text('S${e.key + 1}', style: AppTextStyles.body.copyWith(fontSize: 11))])).toList()))); }
