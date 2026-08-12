import 'package:flutter/material.dart';

import '../features/profile/profile_data.dart';
import 'discovery_helpers.dart';

class DiscoveryPerson {
  const DiscoveryPerson({
    required this.name,
    required this.age,
    required this.distance,
    required this.introduction,
    required this.tags,
    required this.color, {
    this.portrait = '',
    this.verified = false,
    this.availability = '',
    this.bio = '',
    this.city = '',
    this.occupation = '',
    this.lookingFor = '',
    this.lifestyle = const <String>[],
    this.languages = const <String>[],
    this.mutualInterests = const <String>[],
    this.instagram = '',
  });
  final String name;
  final int age;
  final String distance;
  final String introduction;
  final List<String> tags;
  final Color color;
  final String portrait;
  final bool verified;
  final String availability;
  final String bio;
  final String city;
  final String occupation;
  final String lookingFor;
  final List<String> lifestyle;
  final List<String> languages;
  final List<String> mutualInterests;
  final String instagram;
}
