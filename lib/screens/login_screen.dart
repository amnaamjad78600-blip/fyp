import 'package:flutter/material.dart';
import '../services/auth_services.dart';
import 'signup_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  bool isLoading = false;

  /// LOGIN FUNCTION
  void loginUser() async {

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

    try{

      setState(() {
        isLoading = true;
      });

      var user =
      await AuthService().login(email, password);

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

      backgroundColor: const Color(0xffFFF5F8),

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
                      Icons.checkroom_rounded,
                      size: 65,
                      color: Colors.pink,
                    ),
                  ),

                  const SizedBox(height: 25),

                  /// PROJECT TITLE
                  const Text(
                    "AI Fashion App",

                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink,
                      letterSpacing: 1,
                    ),
                  ),

                  const SizedBox(height: 8),

                  /// SUBTITLE
                  const Text(
                    "Smart AI Outfit Recommendation",

                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 40),

                  /// LOGIN CARD
                  Container(

                    padding: const EdgeInsets.all(25),

                    decoration: BoxDecoration(
                      color: Colors.white,

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

                        /// LOGIN TEXT
                        const Text(
                          "Login",

                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink,
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
                              color: Colors.pink,
                            ),

                            filled: true,
                            fillColor:
                            const Color(0xffFFF0F5),

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
                              color: Colors.pink,
                            ),

                            filled: true,
                            fillColor:
                            const Color(0xffFFF0F5),

                            border:
                            OutlineInputBorder(

                              borderRadius:
                              BorderRadius.circular(30),

                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        /// LOGIN BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 55,

                          child: ElevatedButton(

                            onPressed: loginUser,

                            style:
                            ElevatedButton.styleFrom(

                              backgroundColor:
                              Colors.pink,

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

                              "Login",

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

                        /// SIGNUP BUTTON
                        Row(

                          mainAxisAlignment:
                          MainAxisAlignment.center,

                          children: [

                            const Text(
                              "Don't have an account?",
                            ),

                            TextButton(

                              onPressed: (){

                                Navigator.push(
                                  context,

                                  MaterialPageRoute(
                                    builder: (_)
                                    => const SignupScreen(),
                                  ),
                                );
                              },

                              child: const Text(

                                "Signup",

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