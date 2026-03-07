import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/util/ui/visuals.dart';
import 'package:localsend_app/widget/modern/modern_ui.dart';

class PrivacyPolicyDialog extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const PrivacyPolicyDialog({
    required this.onAccept,
    required this.onDecline,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final content = _PrivacyPolicyContent.resolve();
    final compact = context.isNarrowWidth;
    final sectionSpacing = context.adaptiveSectionSpacing;
    final visuals = context.visuals;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 24,
        vertical: compact ? 18 : 28,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 840,
          maxHeight: screenHeight * (compact ? 0.84 : 0.80),
        ),
        child: GlassSurface(
          strong: true,
          blurSigma: visuals.dialogBlur,
          borderRadius: visuals.largeRadius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.dialogs.privacyPolicy.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                t.dialogs.privacyPolicy.subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: visuals.mutedForeground,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Scrollbar(
                  thumbVisibility: !compact,
                  child: SelectionArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(right: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PolicyHeroCard(content: content),
                          SizedBox(height: sectionSpacing),
                          for (var index = 0; index < content.sections.length; index++) ...[
                            _PolicySectionCard(section: content.sections[index]),
                            if (index != content.sections.length - 1)
                              SizedBox(height: sectionSpacing),
                          ],
                          SizedBox(height: sectionSpacing),
                          _PolicyContactCard(content: content),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.only(top: 14),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: visuals.glassBorder)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    TextButton(
                      onPressed: onDecline,
                      child: Text(t.general.decline),
                    ),
                    FilledButton(
                      onPressed: onAccept,
                      child: Text(t.general.accept),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyHeroCard extends StatelessWidget {
  final _PrivacyPolicyContent content;

  const _PolicyHeroCard({required this.content});

  @override
  Widget build(BuildContext context) {
    return GlassSectionCard(
      title: content.heroTitle,
      subtitle: content.heroSubtitle,
      strong: true,
      trailing: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          Icons.verified_user_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          StatusChip(
            label: content.lastUpdated,
            icon: Icons.update_rounded,
            emphasized: true,
            color: Theme.of(context).colorScheme.primary,
          ),
          StatusChip(
            label: content.effectiveDate,
            icon: Icons.event_available_rounded,
          ),
          for (final badge in content.highlights)
            StatusChip(
              label: badge,
              icon: Icons.check_circle_outline_rounded,
            ),
        ],
      ),
    );
  }
}

class _PolicySectionCard extends StatelessWidget {
  final _PrivacyPolicySection section;

  const _PolicySectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          height: 1.58,
        );

    return GlassSectionCard(
      title: section.title,
      applyBlur: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < section.paragraphs.length; index++) ...[
            Text(section.paragraphs[index], style: textStyle),
            if (index != section.paragraphs.length - 1 || section.bullets.isNotEmpty)
              const SizedBox(height: 12),
          ],
          for (var index = 0; index < section.bullets.length; index++) ...[
            _PolicyBulletRow(bullet: section.bullets[index]),
            if (index != section.bullets.length - 1)
              const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PolicyBulletRow extends StatelessWidget {
  final _PrivacyPolicyBullet bullet;

  const _PolicyBulletRow({required this.bullet});

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.58,
        );
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          height: 1.58,
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 10),
          child: Icon(
            Icons.fiber_manual_record_rounded,
            size: 10,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(text: '${bullet.label} ', style: labelStyle),
                TextSpan(text: bullet.body, style: bodyStyle),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PolicyContactCard extends StatelessWidget {
  final _PrivacyPolicyContent content;

  const _PolicyContactCard({required this.content});

  @override
  Widget build(BuildContext context) {
    return GlassSectionCard(
      title: content.contactTitle,
      subtitle: content.contactSubtitle,
      applyBlur: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassSurface(
            applyBlur: false,
            borderRadius: BorderRadius.circular(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.alternate_email_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content.contactEmail,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        content.company,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.visuals.mutedForeground,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: content.contactEmail),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t.general.copiedToClipboard)),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(t.general.copy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyPolicyContent {
  final String heroTitle;
  final String heroSubtitle;
  final String lastUpdated;
  final String effectiveDate;
  final List<String> highlights;
  final List<_PrivacyPolicySection> sections;
  final String contactTitle;
  final String contactSubtitle;
  final String contactEmail;
  final String company;

  const _PrivacyPolicyContent({
    required this.heroTitle,
    required this.heroSubtitle,
    required this.lastUpdated,
    required this.effectiveDate,
    required this.highlights,
    required this.sections,
    required this.contactTitle,
    required this.contactSubtitle,
    required this.contactEmail,
    required this.company,
  });

  static _PrivacyPolicyContent resolve() {
    final languageCode = LocaleSettings.currentLocale.languageCode;
    return languageCode == 'zh' ? _zh : _en;
  }

  static const _PrivacyPolicyContent _zh = _PrivacyPolicyContent(
    heroTitle: '隐私优先，本地优先',
    heroSubtitle: 'AloeSend 基于 LocalSend 构建，专注于局域网传输，而不是云端收集。',
    lastUpdated: '最后更新：2025 年 12 月 5 日',
    effectiveDate: '生效日期：2025 年 1 月 13 日',
    highlights: ['不上传个人数据', '不做行为分析', '主要在本地处理'],
    contactTitle: '联系我们',
    contactSubtitle: '如果你对隐私政策有疑问，可以通过下面的邮箱联系我们。',
    contactEmail: 'aloechat@aloereed.com',
    company: '郴州液态科技有限公司 · 2024–2025',
    sections: [
      _PrivacyPolicySection(
        title: '简介',
        paragraphs: [
          '本隐私政策旨在帮助你了解 AloeSend 在使用过程中可能涉及的信息处理方式。',
          'AloeSend 基于 LocalSend 构建，是一款用于局域网文件传输的开源工具。我们秉承 LocalSend 的隐私保护原则，承诺不主动收集任何用于远程分析的个人数据或非个人数据。',
        ],
      ),
      _PrivacyPolicySection(
        title: '个人数据的收集与使用',
        paragraphs: [
          'AloeSend 以保护用户隐私为前提进行设计。在你使用应用时，相关信息处理遵循以下原则：',
          '为了设备辨识，应用可能会在本地保存设备标识相关信息；这些信息仅用于当前设备上的功能实现，不会主动上传给开发者或第三方。',
          '另外，由于 Flutter 框架的适配机制，系统层可能出现与剪贴板相关的调用尝试；但本应用不会将剪贴板内容上传到网络，也不会将这类内容用于远程收集。',
        ],
        bullets: [
          _PrivacyPolicyBullet(
            label: '个人数据：',
            body: '指可识别个人身份的信息，例如姓名、邮箱地址等。AloeSend 不以云端服务的方式收集或上传这类数据。',
          ),
          _PrivacyPolicyBullet(
            label: '非个人数据：',
            body: '指无法直接识别个人身份的信息，例如匿名化统计结果。AloeSend 不会为了分析、广告或画像目的收集、存储或处理此类数据。',
          ),
        ],
      ),
      _PrivacyPolicySection(
        title: '权限说明',
        paragraphs: [
          'AloeSend 使用 Flutter 生态中的组件来完成核心功能。部分权限仅在对应功能被触发时发挥作用。',
        ],
        bullets: [
          _PrivacyPolicyBullet(
            label: '相机 / 录音：',
            body: '主要用于媒体选择相关插件能力。应用不会自行进行录制，也不会向开发者或第三方传输你的录音录像内容。',
          ),
          _PrivacyPolicyBullet(
            label: '存储：',
            body: '用于保存你从其他设备接收到的文件，以及访问你主动选择分享的本地文件。',
          ),
        ],
      ),
      _PrivacyPolicySection(
        title: '安全性',
        paragraphs: [
          '由于 AloeSend 不依赖云端账户体系，也不以远程服务形式收集传输中的用户数据，因此不会引入常见的云端数据托管风险。',
          '即便如此，我们依然重视应用本身的安全性，并尽量通过可靠的开源实现与本地网络传输设计来保障使用体验。',
        ],
      ),
      _PrivacyPolicySection(
        title: '第三方数据收集',
        paragraphs: [
          '虽然 AloeSend 本身不会主动收集个人或非个人数据，但操作系统、设备制造商或其他具备设备权限的应用，仍可能依据它们各自的规则进行数据处理。',
          '这些第三方行为不在 AloeSend 的控制范围内。建议你同时查阅系统与设备厂商的隐私政策，以获得更完整的信息。',
        ],
      ),
      _PrivacyPolicySection(
        title: '隐私政策的变更',
        paragraphs: [
          '我们可能会不时更新本隐私政策。更新后的版本会在应用内展示，并自发布时起生效。',
          '建议你定期查看本页面，以便及时了解最新条款。',
        ],
      ),
    ],
  );

  static const _PrivacyPolicyContent _en = _PrivacyPolicyContent(
    heroTitle: 'Privacy-first, local-first',
    heroSubtitle: 'AloeSend is based on LocalSend and focuses on local-network transfer rather than cloud collection.',
    lastUpdated: 'Last updated: December 5, 2025',
    effectiveDate: 'Effective date: January 13, 2025',
    highlights: ['No personal uploads', 'No analytics tracking', 'Processed mainly on-device'],
    contactTitle: 'Contact',
    contactSubtitle: 'If you have questions about this privacy policy, you can reach us at the email below.',
    contactEmail: 'aloechat@aloereed.com',
    company: 'Chenzhou Liquid Technology Co., Ltd. · 2024–2025',
    sections: [
      _PrivacyPolicySection(
        title: 'Overview',
        paragraphs: [
          'This privacy policy explains how AloeSend handles information when you use the app.',
          'AloeSend is built on LocalSend and is designed for local network file transfer. We follow a privacy-focused approach and do not actively collect personal data or analytics data for remote services.',
        ],
      ),
      _PrivacyPolicySection(
        title: 'Collection and use of data',
        paragraphs: [
          'AloeSend is designed with user privacy in mind. When you use the app, information is handled according to the principles below.',
          'For device recognition, the app may keep device-identification related information locally on your device. This is used only for local functionality and is not actively transmitted to the developer or third parties.',
          'In addition, Flutter compatibility behavior may trigger clipboard-related checks at the system level. AloeSend does not upload clipboard content to the internet and does not use clipboard data for remote collection.',
        ],
        bullets: [
          _PrivacyPolicyBullet(
            label: 'Personal data:',
            body: 'information that can identify you directly, such as your name or email address. AloeSend does not collect or upload this kind of information as part of a cloud service.',
          ),
          _PrivacyPolicyBullet(
            label: 'Non-personal data:',
            body: 'information that does not directly identify you, such as anonymized statistics. AloeSend does not collect, store, or process this kind of data for analytics, advertising, or profiling.',
          ),
        ],
      ),
      _PrivacyPolicySection(
        title: 'Permissions',
        paragraphs: [
          'AloeSend uses Flutter ecosystem components to provide its core features. Some permissions are only relevant when a related feature is used.',
        ],
        bullets: [
          _PrivacyPolicyBullet(
            label: 'Camera / microphone:',
            body: 'used mainly for media-picker related capabilities. The app does not record on its own and does not transmit your recordings to the developer or third parties.',
          ),
          _PrivacyPolicyBullet(
            label: 'Storage:',
            body: 'used to save files received from other devices and to access files you explicitly choose to share.',
          ),
        ],
      ),
      _PrivacyPolicySection(
        title: 'Security',
        paragraphs: [
          'Because AloeSend does not rely on cloud accounts and does not operate as a remote data collection service, it avoids many common risks associated with hosted user data.',
          'That said, we still take app security seriously and aim to provide a trustworthy experience through open-source implementations and local-network transfer design.',
        ],
      ),
      _PrivacyPolicySection(
        title: 'Third-party collection',
        paragraphs: [
          'While AloeSend itself does not actively collect personal or non-personal data, your operating system, device manufacturer, or other apps with device permissions may handle data under their own policies.',
          'Those third-party behaviors are outside AloeSend’s control. We recommend reviewing your system and device vendor privacy policies for a fuller picture.',
        ],
      ),
      _PrivacyPolicySection(
        title: 'Policy changes',
        paragraphs: [
          'We may update this privacy policy from time to time. Updated versions will be shown in the app and take effect when published.',
          'We recommend checking this page periodically to stay informed about the latest terms.',
        ],
      ),
    ],
  );
}

class _PrivacyPolicySection {
  final String title;
  final List<String> paragraphs;
  final List<_PrivacyPolicyBullet> bullets;

  const _PrivacyPolicySection({
    required this.title,
    this.paragraphs = const [],
    this.bullets = const [],
  });
}

class _PrivacyPolicyBullet {
  final String label;
  final String body;

  const _PrivacyPolicyBullet({
    required this.label,
    required this.body,
  });
}
