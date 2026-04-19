import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomeController extends GetxController {
  TextEditingController searchController = TextEditingController();
  TextEditingController notesController = TextEditingController();
  TextEditingController inspectorController = TextEditingController();
  TextEditingController otherIssueController = TextEditingController();

  bool isBusy = false;

  void clearInputData() {
    searchController.text = "";
  }
}
