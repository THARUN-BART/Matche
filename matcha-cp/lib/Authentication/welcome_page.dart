import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:matcha/Authentication/Login.dart';
import 'package:matcha/Authentication/sign_up.dart';

class welcome_page extends StatefulWidget {
  const welcome_page({super.key});

  @override
  State<welcome_page> createState() => _welcome_pageState();
}

class _welcome_pageState extends State<welcome_page> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 50),

          // Welcome text
          Padding(
            padding: const EdgeInsets.all(25),
            child: Text(
              "Welcome",
              style: GoogleFonts.salsa(
                color: Color(0xFFFFEC3D),
                fontSize: 35,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // TO text
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "To",
                style: GoogleFonts.salsa(
                  color: Color(0xFFFFEC3D),
                  fontSize: 35,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // First star
              Icon(
                Icons.star,
                color: Color(0xFFFFEC3D),
                size: 30,
              ),
              SizedBox(width: 5),
              Transform.translate(
                offset: Offset(0, -10),
                child: Icon(
                  Icons.star,
                  color: Color(0xFFFFEC3D),
                  size: 20,
                ),
              ),
              SizedBox(width: 10),
              // MATCHE text
              Text(
                "MATCHE",
                style: GoogleFonts.salsa(
                  color: Color(0xFFFFEC3D),
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          SizedBox(height: 80),

          // Login button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => Login()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  side: BorderSide(color: Colors.white, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  "Login",
                  style: GoogleFonts.salsa(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 20),

          // Sign Up button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) =>Signup()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFFEC3D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  "Sign Up",
                  style: GoogleFonts.salsa(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 50),
        ],
      ),
    );
  }
}