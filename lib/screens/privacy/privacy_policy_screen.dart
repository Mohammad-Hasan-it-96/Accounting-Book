import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سياسة الخصوصية')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _PolicySection(
            title: 'المقدمة',
            body:
                'تطبيق "دفتر حسابات" مُصمَّم لمساعدة أصحاب المشاريع الصغيرة على إدارة حسابات عملائهم '
                'بطريقة بسيطة وآمنة. نحن نُولي حماية بياناتك الشخصية أهمية بالغة.',
          ),
          _PolicySection(
            title: 'البيانات التي نجمعها',
            body:
                '• بيانات العملاء والحركات المالية التي تُدخلها بنفسك.\n'
                '• اسمك ورقم هاتفك عند طلب تفعيل التطبيق.\n'
                '• معرّف جهازك (مُشفَّر بخوارزمية SHA-256) لأغراض الترخيص فقط.',
          ),
          _PolicySection(
            title: 'كيف نستخدم البيانات',
            body:
                '• بيانات العملاء والحركات تُحفَظ محلياً على جهازك فقط ولا تُرسَل إلى أي خادم.\n'
                '• بيانات التفعيل (الاسم والهاتف ومعرّف الجهاز) تُرسَل إلى خادمنا لتفعيل الترخيص.\n'
                '• لا نبيع بياناتك لأطراف ثالثة ولا نستخدمها لأغراض إعلانية.',
          ),
          _PolicySection(
            title: 'النسخ الاحتياطي',
            body:
                'ملفات النسخ الاحتياطي تُحفَظ على جهازك أو في التخزين الخارجي الذي تختاره. '
                'التطبيق لا يرفع نسخاً احتياطية تلقائياً إلى أي خادم سحابي.',
          ),
          _PolicySection(
            title: 'الأمان',
            body:
                'نستخدم معرّفات مُشفَّرة لحماية بيانات الترخيص. '
                'يمكنك تفعيل قفل PIN لمنع الوصول غير المصرح به للتطبيق.',
          ),
          _PolicySection(
            title: 'حقوقك',
            body:
                'يمكنك في أي وقت:\n'
                '• حذف جميع بياناتك بإلغاء تثبيت التطبيق.\n'
                '• التواصل معنا لطلب حذف بيانات التفعيل من الخادم.',
          ),
          _PolicySection(
            title: 'التواصل',
            body:
                'لأي استفسار بخصوص سياسة الخصوصية أو بياناتك، تواصل معنا عبر '
                'واتساب أو تيليغرام من قسم "الدعم الفني" في الإعدادات.',
          ),
          _PolicySection(
            title: 'التحديثات',
            body:
                'قد نُحدِّث هذه السياسة من حين لآخر. سيتم إشعارك بأي تغييرات جوهرية '
                'عبر تحديثات التطبيق.',
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String body;

  const _PolicySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }
}
