import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showEditProfileDialog() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user != null) {
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
      _emailController.text = user.email;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubah Profil'),
        content: Form(
          key: _profileFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'Nama Depan'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Nama Belakang'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email tidak boleh kosong';
                    }
                    final emailRegex = RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,4}$');
                    if (!emailRegex.hasMatch(value)) {
                      return 'Format email tidak valid';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!_profileFormKey.currentState!.validate()) return;

              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              final success = await authProvider.updateProfile(
                firstName: _firstNameController.text.trim(),
                lastName: _lastNameController.text.trim(),
                email: _emailController.text.trim(),
              );

              if (success) {
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Profil berhasil diperbarui.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                        authProvider.errorMessage ?? 'Gagal memperbarui profil.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    _oldPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ganti Password'),
        content: Form(
          key: _passwordFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _oldPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password Lama'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Masukkan password lama';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password Baru'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Masukkan password baru';
                    }
                    if (value.length < 8) {
                      return 'Password minimal 8 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Konfirmasi Password Baru'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Konfirmasi password baru';
                    }
                    if (value != _newPasswordController.text) {
                      return 'Password tidak cocok';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!_passwordFormKey.currentState!.validate()) return;

              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);

              final success = await authProvider.changePassword(
                _oldPasswordController.text,
                _newPasswordController.text,
              );

              if (success) {
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Password berhasil diganti.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                        authProvider.errorMessage ?? 'Gagal mengganti password.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar Aplikasi'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun Anda?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // Clear order data sebelum logout agar tidak bocor ke user lain
      Provider.of<OrderProvider>(context, listen: false).clear();
      await Provider.of<AuthProvider>(context, listen: false).logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    String formattedJoinedDate = '';
    if (user != null) {
      try {
        final parsed = DateTime.parse(user.dateJoined).toLocal();
        formattedJoinedDate = DateFormat('dd MMMM yyyy').format(parsed);
      } catch (_) {
        formattedJoinedDate = user.dateJoined;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: Text('Profil tidak ditemukan.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Header
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 24.0, horizontal: 16.0),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: user.isAdmin
                                ? Colors.indigo
                                : Colors.teal,
                            child: const Icon(Icons.person,
                                size: 48, color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            user.fullName,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${user.username}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          // Badge role
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: user.isAdmin
                                  ? Colors.indigo[50]
                                  : Colors.teal[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              user.isAdmin ? 'Admin' : 'User',
                              style: TextStyle(
                                color: user.isAdmin
                                    ? Colors.indigo[700]
                                    : Colors.teal[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            user.email,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Bergabung sejak: $formattedJoinedDate',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Menu pengaturan
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit_outlined,
                              color: Colors.indigo),
                          title: const Text('Ubah Informasi Profil'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showEditProfileDialog,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.lock_outline,
                              color: Colors.indigo),
                          title: const Text('Ganti Password'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showChangePasswordDialog,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Tombol logout
                  ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text(
                      'Keluar dari Akun',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
