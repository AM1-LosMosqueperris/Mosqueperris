
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReservasCitasScreen extends StatefulWidget {
  final String? servicioInicial;

  const ReservasCitasScreen({
    super.key,
    this.servicioInicial,
  });

  @override
  State<ReservasCitasScreen> createState() =>
      _ReservasCitasScreenState();
}

class _ReservasCitasScreenState extends State<ReservasCitasScreen> {
  final _formKey = GlobalKey<FormState>();

  final propietarioController = TextEditingController();
  final mascotaController = TextEditingController();
  final comentarioController = TextEditingController();
  final telefonoController = TextEditingController();
  final personasController = TextEditingController();

  final List<String> servicios = [
    'Consulta veterinaria',
    'Vacunación',
    'Desparasitación',
    'Peluquería',
    'Control y seguimiento',
    'Laboratorio',
  ];

  String? servicioSeleccionado;
  DateTime? fechaSeleccionada;
  TimeOfDay? horaSeleccionada;

  bool _enviando = false;

  final List<Map<String, String>> citas = [];

  @override
  void initState() {
    super.initState();

    if (servicios.contains(widget.servicioInicial)) {
      servicioSeleccionado = widget.servicioInicial;
    }
  }

  @override
  void didUpdateWidget(covariant ReservasCitasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.servicioInicial != widget.servicioInicial) {
      servicioSeleccionado =
          servicios.contains(widget.servicioInicial)
              ? widget.servicioInicial
              : null;
    }
  }

  Future<void> seleccionarFecha() async {
    final ahora = DateTime.now();

    final fecha = await showDatePicker(
      context: context,
      initialDate: fechaSeleccionada != null &&
              !fechaSeleccionada!.isBefore(
                DateTime(ahora.year, ahora.month, ahora.day),
              )
          ? fechaSeleccionada!
          : DateTime(ahora.year, ahora.month, ahora.day),
      firstDate: DateTime(ahora.year, ahora.month, ahora.day),
      lastDate: ahora.add(const Duration(days: 365)),
      helpText: 'Seleccionar fecha de la cita',
    );

    if (fecha != null && mounted) {
      setState(() {
        fechaSeleccionada = fecha;
      });
    }
  }

  Future<void> seleccionarHora() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: horaSeleccionada ?? TimeOfDay.now(),
      helpText: 'Seleccionar hora de la cita',
    );

    if (hora != null && mounted) {
      setState(() {
        horaSeleccionada = hora;
      });
    }
  }

  Future<void> solicitarCita() async {
    if (_enviando) return;

    if (!_formKey.currentState!.validate()) return;

    if (servicioSeleccionado == null ||
        fechaSeleccionada == null ||
        horaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa el servicio, la fecha y la hora.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final fecha = fechaSeleccionada!;
    final hora = horaSeleccionada!;

    final fechaHoraReserva = DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
      hora.hour,
      hora.minute,
    );

    if (!fechaHoraReserva.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No puedes seleccionar una fecha u hora pasada.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _enviando = true;
    });

    try {
      await Supabase.instance.client.from('reservas').insert({
        'nombre': propietarioController.text.trim(),
        'telefono': telefonoController.text.trim(),
        'fecha':
            '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}',
        'hora':
            '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}:00',
        'personas': int.parse(personasController.text.trim()),
      });

      if (!mounted) return;

      setState(() {
        citas.add({
          'propietario': propietarioController.text.trim(),
          'mascota': mascotaController.text.trim(),
          'servicio': servicioSeleccionado!,
          'fecha': '${fecha.day}/${fecha.month}/${fecha.year}',
          'hora': hora.format(context),
          'comentario': comentarioController.text.trim(),
          'telefono': telefonoController.text.trim(),
          'personas': personasController.text.trim(),
        });
      });

      propietarioController.clear();
      mascotaController.clear();
      comentarioController.clear();
      telefonoController.clear();
      personasController.clear();

      setState(() {
        servicioSeleccionado = null;
        fechaSeleccionada = null;
        horaSeleccionada = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '¡Reserva guardada correctamente en Supabase!',
          ),
          backgroundColor: Color(0xFF269B79),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
          'No se pudo enviar la consulta. Verifica tu conexión e inténtalo nuevamente.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _enviando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    propietarioController.dispose();
    mascotaController.dispose();
    comentarioController.dispose();
    telefonoController.dispose();
    personasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reserva de citas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.calendar_month,
                  size: 65,
                  color: Color(0xFF269B79),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Solicita una cita veterinaria',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Completa los datos para programar la atención de tu mascota.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 25),

                Card(
                  color: Colors.white,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: propietarioController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del propietario',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return 'Ingresa el nombre del propietario';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: telefonoController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Teléfono',
                              hintText: 'Ej. 71234567',
                              prefixIcon: Icon(Icons.phone),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return 'Ingresa tu teléfono';
                              }
                              if (!RegExp(r'^[67][0-9]{7}$')
                                  .hasMatch(value.trim())) {
                                return 'Debe tener 8 dígitos y comenzar con 6 o 7';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: mascotaController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre de la mascota',
                              prefixIcon: Icon(Icons.pets),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return 'Ingresa el nombre de la mascota';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          DropdownButtonFormField<String>(
                            key: ValueKey(servicioSeleccionado),
                            initialValue: servicioSeleccionado,
                            decoration: const InputDecoration(
                              labelText: 'Servicio',
                              prefixIcon:
                                  Icon(Icons.medical_services),
                              border: OutlineInputBorder(),
                            ),
                            items: servicios.map((servicio) {
                              return DropdownMenuItem(
                                value: servicio,
                                child: Text(servicio),
                              );
                            }).toList(),
                            onChanged: _enviando
                                ? null
                                : (value) {
                                    setState(() {
                                      servicioSeleccionado = value;
                                    });
                                  },
                            validator: (value) {
                              if (value == null) {
                                return 'Selecciona un servicio';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          InkWell(
                            onTap: _enviando ? null : seleccionarFecha,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Fecha de la cita',
                                prefixIcon:
                                    Icon(Icons.calendar_today),
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                fechaSeleccionada == null
                                    ? 'Seleccionar fecha'
                                    : '${fechaSeleccionada!.day}/'
                                        '${fechaSeleccionada!.month}/'
                                        '${fechaSeleccionada!.year}',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          InkWell(
                            onTap: _enviando ? null : seleccionarHora,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Hora de la cita',
                                prefixIcon: Icon(Icons.access_time),
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                horaSeleccionada == null
                                    ? 'Seleccionar hora'
                                    : horaSeleccionada!.format(context),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: personasController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cantidad de personas',
                              hintText: 'Entre 1 y 50',
                              prefixIcon: Icon(Icons.people),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final cantidad =
                                  int.tryParse(value ?? '');

                              if (cantidad == null) {
                                return 'Ingresa una cantidad válida';
                              }
                              if (cantidad < 1 || cantidad > 50) {
                                return 'Debe ser entre 1 y 50 personas';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: comentarioController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Comentario (opcional)',
                              hintText:
                                  'Escribe algún detalle adicional...',
                              prefixIcon: Icon(Icons.comment),
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 22),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _enviando ? null : solicitarCita,
                              icon: _enviando
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.event_available),
                              label: Text(
                                _enviando
                                    ? 'Guardando reserva...'
                                    : 'Solicitar cita',
                                style: const TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF269B79),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  'Citas solicitadas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                if (citas.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Todavía no hay citas solicitadas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),

                ...citas.asMap().entries.map((entry) {
                  final index = entry.key;
                  final cita = entry.value;

                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE0F2EC),
                        child: Icon(
                          Icons.calendar_month,
                          color: Color(0xFF269B79),
                        ),
                      ),
                      title: Text(
                        cita['mascota']!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Propietario: ${cita['propietario']}\n'
                        'Servicio: ${cita['servicio']}\n'
                        'Fecha: ${cita['fecha']} - ${cita['hora']}',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          setState(() {
                            citas.removeAt(index);
                          });
                        },
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
