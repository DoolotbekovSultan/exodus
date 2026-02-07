import 'package:exodus/data/db/requests_db.dart';
import 'package:exodus/data/model/request.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});
  @override
  State<StatefulWidget> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  final db = RequestDb();
  List<Request> requests = [];
  bool isLoading = true;
  bool showTime = false;
  DateTime? filterDay;

  Future<void> loadRequests() async {
    final data = filterDay == null
        ? await db.getAll()
        : await db.getByDay(filterDay!);
    setState(() {
      requests = data;
      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  String _formatTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}';
  }

  String _formatDay(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _canAdd =>
      filterDay == null || _isSameDay(filterDay!, DateTime.now());

  String _formatLine(Request e, {bool includeId = false}) {
    final status = e.label();
    final time = _formatTime(e.createdAt);
    final commentPart = (e.comment?.isNotEmpty ?? false)
        ? ' "${e.comment}"'
        : '';
    const colStart = 14;
    final padCount = status.length >= colStart ? 1 : (colStart - status.length);
    final padded = '$status${' ' * padCount}$time$commentPart';
    return includeId ? '${e.id} - $padded' : padded;
  }

  Future<void> pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: filterDay ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        filterDay = picked;
        isLoading = true;
      });
      await loadRequests();
    }
  }

  Future<void> addOrEdit(Request? existing) async {
    final idController = TextEditingController(text: existing?.id ?? '');
    RequestStatus status = existing?.status ?? RequestStatus.resolved;
    final languageController = TextEditingController(
      text: existing?.language ?? '',
    );
    final commentController = TextEditingController(
      text: existing?.comment ?? '',
    );

    final result = await showDialog<Request>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                existing == null ? 'Добавить заявку' : 'Редактировать заявку',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: idController,
                      decoration: const InputDecoration(labelText: 'ID'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<RequestStatus>(
                      initialValue: status,
                      items: RequestStatus.values
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                e == RequestStatus.secondLine
                                    ? '2 лин'
                                    : e.toString(),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setStateDialog(() {
                            status = v;
                          });
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Статус'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: languageController,
                      decoration: const InputDecoration(
                        labelText: 'Язык (например, узбек, таджикский)',
                      ),
                      enabled: status == RequestStatus.languageNeeded,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: commentController,
                      decoration: const InputDecoration(
                        labelText: 'Комментарий',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final req = Request(
                      id: idController.text.trim(),
                      status: status,
                      language: languageController.text.trim().isEmpty
                          ? null
                          : languageController.text.trim(),
                      comment: commentController.text.trim().isEmpty
                          ? null
                          : commentController.text.trim(),
                    );
                    Navigator.pop(context, req);
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      if (existing == null) {
        await db.insert(result);
        if (!mounted) return;
        Clipboard.setData(ClipboardData(text: _formatLine(result)));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Скопировано: ${_formatLine(result)}')),
        );
      } else {
        await db.update(result);
      }
      await loadRequests();
    }
  }

  Future<void> exportText() async {
    final headerDate = _formatDay(filterDay ?? DateTime.now());

    // Формируем строки
    final rows = requests.map((e) {
      final left = '${e.id} - ${e.label()}';
      final time = _formatTime(e.createdAt);
      final comment = (e.comment?.isNotEmpty ?? false) ? ' "${e.comment}"' : '';
      return {'left': left, 'time': time, 'comment': comment};
    }).toList();

    final maxLeft = rows.fold<int>(0, (m, r) {
      final width = r['left']!.runes.length; // учитываем кириллицу
      return width > m ? width : m;
    });

    final body = rows
        .map((r) {
          final spacesCount = maxLeft - r['left']!.runes.length + 3;
          final spaces = ' ' * spacesCount;
          return '${r['left']}$spaces${r['time']}${r['comment']}';
        })
        .join('\n');

    final text =
        'Дата: $headerDate\n-------------------------------------------------------------------\n$body';

    // Копируем в буфер
    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Текст скопирован')));

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Текст скопирован'),
          content: SingleChildScrollView(child: Text(text)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(Object context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          filterDay == null ? 'Заявки' : 'Заявки · ${_formatDay(filterDay!)}',
        ),
        actions: [
          IconButton(
            onPressed: exportText,
            icon: const Icon(Icons.content_copy),
          ),
          IconButton(
            onPressed: () => setState(() => showTime = !showTime),
            icon: Icon(showTime ? Icons.schedule : Icons.schedule_outlined),
            tooltip: 'Показать время',
          ),
          IconButton(
            onPressed: pickDay,
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Выбрать день',
          ),
          if (filterDay != null)
            IconButton(
              onPressed: () async {
                setState(() {
                  filterDay = null;
                  isLoading = true;
                });
                await loadRequests();
              },
              icon: const Icon(Icons.clear),
              tooltip: 'Сбросить фильтр',
            ),
        ],
      ),
      body: isLoading
          ? const CircularProgressIndicator()
          : ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return ListTile(
                  title: Text(request.id),
                  subtitle: Text(
                    showTime
                        ? '${request.label()} • ${_formatTime(request.createdAt)}'
                        : request.label(),
                  ),
                  onTap: () => addOrEdit(request),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'copy_formatted':
                          Clipboard.setData(
                            ClipboardData(text: _formatLine(request)),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Скопировано')),
                          );
                          break;
                        case 'copy_status':
                          Clipboard.setData(
                            ClipboardData(text: request.label()),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Скопировано')),
                          );
                          break;
                        case 'copy_time':
                          Clipboard.setData(
                            ClipboardData(text: _formatTime(request.createdAt)),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Скопировано')),
                          );
                          break;
                        case 'copy_id':
                          Clipboard.setData(ClipboardData(text: request.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Скопировано')),
                          );
                          break;
                        case 'delete':
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Удалить заявку?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(
                                    context,
                                    false,
                                  ), // return false
                                  child: const Text('Нет'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(
                                    context,
                                    true,
                                  ), // return true
                                  child: const Text('Да'),
                                ),
                              ],
                            ),
                          );

                          if (result == true) {
                            await db.delete(request.id);
                            await loadRequests();
                          }

                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'copy_formatted',
                        child: Text('Копировать'),
                      ),
                      PopupMenuItem(
                        value: 'copy_status',
                        child: Text('Копировать статус'),
                      ),
                      PopupMenuItem(
                        value: 'copy_time',
                        child: Text('Копировать время'),
                      ),
                      PopupMenuItem(
                        value: 'copy_id',
                        child: Text('Копировать ID'),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(value: 'delete', child: Text('Удалить')),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: _canAdd
          ? FloatingActionButton(
              onPressed: () => addOrEdit(null),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
