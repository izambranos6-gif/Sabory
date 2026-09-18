part of '../main.dart';

// ============================================================
// WIDGETS
// ============================================================

class SummaryCard
    extends StatelessWidget {
  final String title;
  final String value;

  final IconData icon;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          14,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(
              height: 8,
            ),
            Text(
              title,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              value,
              style:
                  const TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryCard
    extends StatelessWidget {
  final String emoji;
  final String title;

  final int quantity;
  final double amount;

  const CategoryCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.quantity,
    required this.amount,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: ListTile(
        leading:
            CircleAvatar(
          child: Text(emoji),
        ),
        title: Text(
          title,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '$quantity vendidos',
        ),
        trailing: Text(
          money(amount),
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class TotalBox
    extends StatelessWidget {
  final String title;

  final double value;

  final String subtitle;

  const TotalBox({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color:
            Theme.of(context)
                .colorScheme
                .primaryContainer
                .withOpacity(
                  0.45,
                ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            money(value),
            style:
                const TextStyle(
              fontSize: 28,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            textAlign:
                TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class SectionTitle
    extends StatelessWidget {
  final IconData icon;
  final String title;

  const SectionTitle({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 7),
          Text(
            title,
            style:
                const TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 58,
              color:
                  Colors.grey.shade400,
            ),
            const SizedBox(
              height: 12,
            ),
            Text(
              title,
              style:
                  const TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              subtitle,
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusBadge
    extends StatelessWidget {
  final String text;

  final bool positive;

  const StatusBadge({
    super.key,
    required this.text,
    required this.positive,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: positive
            ? Colors.green.shade50
            : Colors.orange.shade50,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight:
              FontWeight.bold,
          color: positive
              ? Colors.green.shade800
              : Colors.orange.shade800,
        ),
      ),
    );
  }
}

class CashCloseRow
    extends StatelessWidget {
  final String label;

  final double value;

  final bool strong;

  const CashCloseRow({
    super.key,
    required this.label,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: strong
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '${value < 0 ? '-' : ''}'
            '${money(value.abs())}',
            style: TextStyle(
              fontWeight: strong
                  ? FontWeight.bold
                  : FontWeight.w600,
              color: value < 0
                  ? Colors.red
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class DateSelector
    extends StatelessWidget {
  final String title;

  final DateTime date;

  final VoidCallback onTap;

  const DateSelector({
    super.key,
    required this.title,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      borderRadius:
          BorderRadius.circular(
        14,
      ),
      onTap: onTap,
      child: InputDecorator(
        decoration:
            InputDecoration(
          labelText: title,
          prefixIcon:
              const Icon(
            Icons.calendar_month,
          ),
        ),
        child:
            Text(
          formatDate(date),
        ),
      ),
    );
  }
}

class FilterDateButton
    extends StatelessWidget {
  final String label;

  final DateTime? date;

  final VoidCallback onPressed;

  const FilterDateButton({
    super.key,
    required this.label,
    required this.date,
    required this.onPressed,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon:
          const Icon(
        Icons.calendar_month,
      ),
      label: Text(
        '$label\n${date == null ? 'Sin fecha' : formatDate(date!)}',
        textAlign:
            TextAlign.center,
      ),
    );
  }
}

class InfoBox
    extends StatelessWidget {
  final String text;

  const InfoBox({
    super.key,
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration: BoxDecoration(
        color:
            Colors.orange.shade50,
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child: Text(text),
    );
  }
}
