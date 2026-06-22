import 'package:flutter/material.dart';
import '../services/auth_services.dart';
import 'home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  bool isLoading = false;

  /// SIGNUP FUNCTION
  void signupUser() async {

    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if(email.isEmpty || password.isEmpty){
      showError("Please fill all fields");
      return;
    }

    if(!email.contains("@gmail.com")){
      showError("Enter valid Gmail");
      return;
    }

    if(!RegExp(r'^(?=.*[!@#\$%^&*])').hasMatch(password)){
      showError("Password must contain special character");
      return;
    }

    try{

      setState(() {
        isLoading = true;
      });

      var user =
      await AuthService().signup(email, password);

      if(user != null){

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeScreen(
              skinTone: "Fair",
              bodyType: "Slim",
              style: "Casual",
              occasion: "Daily",
            ),
          ),
        );
      }

    } catch(e){

      showError(e.toString());

    }

    setState(() {
      isLoading = false;
    });
  }

  /// ERROR
  void showError(String msg){

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(msg),
      ),
    );
  }

  @override
  Widget build(BuildContext context){

    return Scaffold(

      backgroundColor: const Color(0xFFFFC1E3), // richer pink background

      body: SafeArea(

        child: Center(

          child: SingleChildScrollView(

            child: Padding(
              padding: const EdgeInsets.all(20),

              child: Column(

                mainAxisAlignment:
                MainAxisAlignment.center,

                children: [

                  /// LOGO
                  Container(
                    height: 120,
                    width: 120,

                    decoration: BoxDecoration(
                      color: Colors.white,

                      borderRadius:
                      BorderRadius.circular(35),

                      boxShadow: const [

                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 15,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),

                    child: const Icon(
                      Icons.auto_awesome,
                      size: 65,
                      color: const Color(0xFFF48FB1), // pink accent
                    ),
                  ),

                  const SizedBox(height: 25),

                  /// TITLE
                  const Text(
                    "AI Fashion App",

                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFF48FB1), // pink accent
                      letterSpacing: 1,
                    ),
                  ),

                  const SizedBox(height: 8),

                  /// SUBTITLE
                  const Text(
                    "Create Your Fashion Account",

                    style: TextStyle(
                      fontSize: 15,
                      color: const Color(0xFFF48FB1),
                    ),
                  ),

                  const SizedBox(height: 40),

                  /// SIGNUP CARD
                  Container(

                    padding: const EdgeInsets.all(25),

                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE4ED), // light pink background for card
                // updated container background color


                      borderRadius:
                      BorderRadius.circular(30),

                      boxShadow: const [

                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 12,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),

                    child: Column(

                      children: [

                        /// SIGNUP TEXT
                        const Text(
                          "Signup",

                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFF48FB1), // pink accent
                          ),
                        ),

                        const SizedBox(height: 30),

                        /// EMAIL FIELD
                        TextField(

                          controller: emailController,

                          decoration: InputDecoration(

                            hintText: "Enter Gmail",

                            prefixIcon: const Icon(
                              Icons.email,
                              color: const Color(0xFFF48FB1),
                            ),

                            filled: true,
            fillColor: const Color(0xFFFFE4ED),

                            border:
                            OutlineInputBorder(

                              borderRadius:
                              BorderRadius.circular(30),

                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// PASSWORD FIELD
                        TextField(

                          controller: passwordController,
                          obscureText: true,

                          decoration: InputDecoration(

                            hintText: "Enter Password",

                            prefixIcon: const Icon(
                              Icons.lock,
                              color: const Color(0xFFF48FB1),
                            ),

                            filled: true,
                            fillColor: const Color(0xFFFFE4ED),

                            border:
                            OutlineInputBorder(

                              borderRadius:
                              BorderRadius.circular(30),

                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        /// SIGNUP BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 55,

                          child: ElevatedButton(

                            onPressed: signupUser,

                            style:
                            ElevatedButton.styleFrom(

                              backgroundColor: const Color(0xFFF48FB1),
                              

                              shape:
                              RoundedRectangleBorder(

                                borderRadius:
                                BorderRadius.circular(30),
                              ),
                            ),

                            child: isLoading

                                ? const CircularProgressIndicator(
                              color: Colors.white,
                            )

                                : const Text(

                              "Signup",

                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// LOGIN TEXT
                        Row(

                          mainAxisAlignment:
                          MainAxisAlignment.center,

                          children: [

                            const Text(
                              "Already have an account?",
                            ),

                            TextButton(

                              onPressed: (){
                                Navigator.pop(context);
                              },

                              child: const Text(

                                "Login",

                                style: TextStyle(
                                  color: Colors.pink,
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}