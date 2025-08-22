import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class IconMapper {
  // Map of common icon codePoints from admin portal to Flutter icons
  static final Map<int, IconData> _iconMap = {
    // Games icons
    0xf522: FontAwesomeIcons.dice,
    0xf525: FontAwesomeIcons.diceOne,
    0xf528: FontAwesomeIcons.diceTwo,
    0xf527: FontAwesomeIcons.diceThree,
    0xf524: FontAwesomeIcons.diceFour,
    0xf523: FontAwesomeIcons.diceFive,
    0xf526: FontAwesomeIcons.diceSix,
    0xf11b: FontAwesomeIcons.gamepad,
    0xf439: FontAwesomeIcons.chess,
    0xf441: FontAwesomeIcons.chessKnight,
    0xf447: FontAwesomeIcons.chessRook,
    0xf12e: FontAwesomeIcons.puzzlePiece,
    0xe14f: Icons.casino,
    0xea23: Icons.sports_esports,

    // Sports icons
    0xf44e: FontAwesomeIcons.football,
    0xf434: FontAwesomeIcons.basketballBall,
    0xf433: FontAwesomeIcons.baseball,
    0xf436: FontAwesomeIcons.bowlingBall,
    0xf450: FontAwesomeIcons.golfBallTee,
    0xf45d: FontAwesomeIcons.tableTennisPaddleBall,
    0xf45f: FontAwesomeIcons.volleyball,
    0xf44b: FontAwesomeIcons.dumbbell,
    0xea1c: Icons.sports_soccer,
    0xea1e: Icons.sports_tennis,
    0xea18: Icons.sports_hockey,
    0xea15: Icons.sports_golf,
    0xe1b3: Icons.fitness_center,

    // Entertainment icons
    0xf001: FontAwesomeIcons.music,
    0xf008: FontAwesomeIcons.film,
    0xf26c: FontAwesomeIcons.tv,
    0xf130: FontAwesomeIcons.microphone,
    0xf7a6: FontAwesomeIcons.guitar,
    0xf569: FontAwesomeIcons.drum,
    0xf025: FontAwesomeIcons.headphones,
    0xf3ff: FontAwesomeIcons.ticket,
    0xe02c: Icons.movie,
    0xea66: Icons.theater_comedy,
    0xe3a1: Icons.music_note,
    0xe029: Icons.mic,

    // Food icons
    0xf805: FontAwesomeIcons.burger,
    0xf818: FontAwesomeIcons.pizzaSlice,
    0xf810: FontAwesomeIcons.iceCream,
    0xf563: FontAwesomeIcons.cookieBite,
    0xf1fd: FontAwesomeIcons.cakeCandles,
    0xf0f4: FontAwesomeIcons.coffee,
    0xf561: FontAwesomeIcons.martiniGlass,
    0xf0fc: FontAwesomeIcons.beer,
    0xe56c: Icons.restaurant,
    0xe553: Icons.local_pizza,
    0xe7e9: Icons.cake,
    0xe540: Icons.local_bar,

    // Animals icons
    0xf6d3: FontAwesomeIcons.dog,
    0xf6be: FontAwesomeIcons.cat,
    0xf6f0: FontAwesomeIcons.horse,
    0xf578: FontAwesomeIcons.fish,
    0xf6d7: FontAwesomeIcons.dove,
    0xf6ec: FontAwesomeIcons.hippo,
    0xf6de: FontAwesomeIcons.dragon,
    0xf77c: FontAwesomeIcons.spider,
    0xe91d: Icons.pets,

    // Travel icons
    0xf072: FontAwesomeIcons.plane,
    0xf1b9: FontAwesomeIcons.car,
    0xf207: FontAwesomeIcons.bus,
    0xf238: FontAwesomeIcons.train,
    0xf21a: FontAwesomeIcons.ship,
    0xf206: FontAwesomeIcons.bicycle,
    0xf5a0: FontAwesomeIcons.motorcycle,
    0xf197: FontAwesomeIcons.rocket,
    0xe539: Icons.flight,
    0xe530: Icons.directions_car,
    0xe531: Icons.directions_bus,
    0xe570: Icons.train,

    // Education icons
    0xf02d: FontAwesomeIcons.book,
    0xf19d: FontAwesomeIcons.graduationCap,
    0xf303: FontAwesomeIcons.pencil,
    0xf0eb: FontAwesomeIcons.lightbulb,
    0xf19c: FontAwesomeIcons.school,
    0xf5da: FontAwesomeIcons.bookOpen,
    0xf518: FontAwesomeIcons.chalkboardUser,
    0xf0c0: FontAwesomeIcons.users,
    0xe80c: Icons.school,
    0xe865: Icons.book,

    // Technology icons
    0xf108: FontAwesomeIcons.desktop,
    0xf109: FontAwesomeIcons.laptop,
    0xf10b: FontAwesomeIcons.mobile,
    0xf09b: FontAwesomeIcons.github,
    0xf121: FontAwesomeIcons.code,
    0xf120: FontAwesomeIcons.terminal,
    0xf7cd: FontAwesomeIcons.database,
    0xf013: FontAwesomeIcons.gear,
    0xe30a: Icons.computer,
    0xe32c: Icons.laptop,
    0xe325: Icons.phone_android,
    0xe86f: Icons.code,

    // Nature icons
    0xf185: FontAwesomeIcons.sun,
    0xf186: FontAwesomeIcons.moon,
    0xf0c2: FontAwesomeIcons.cloud,
    0xf06c: FontAwesomeIcons.leaf,
    0xf1bb: FontAwesomeIcons.tree,
    0xf4e3: FontAwesomeIcons.mountain,
    0xf773: FontAwesomeIcons.water,
    0xf06d: FontAwesomeIcons.fire,
    0xe518: Icons.wb_sunny,
    0xea6a: Icons.nights_stay,
    0xe42d: Icons.cloud,
    0xe41a: Icons.eco,

    // Business icons
    0xf0b1: FontAwesomeIcons.briefcase,
    0xf1ad: FontAwesomeIcons.building,
    0xf201: FontAwesomeIcons.chartLine,
    0xf200: FontAwesomeIcons.chartPie,
    0xf080: FontAwesomeIcons.chartBar,
    0xf2b9: FontAwesomeIcons.handshake,
    0xf0d6: FontAwesomeIcons.moneyBillWave,
    0xf19b: FontAwesomeIcons.buildingColumns,
    0xe8f9: Icons.business,
    0xe0af: Icons.business_center,
    0xe6c4: Icons.show_chart,
    0xe6c5: Icons.pie_chart,

    // Medical icons
    0xf0f0: FontAwesomeIcons.userDoctor,
    0xf0f9: FontAwesomeIcons.truckMedical,
    0xf0fe: FontAwesomeIcons.hospital,
    0xf479: FontAwesomeIcons.syringe,
    0xf484: FontAwesomeIcons.pills,
    0xf21e: FontAwesomeIcons.heartPulse,
    0xf487: FontAwesomeIcons.thermometer,
    0xf48e: FontAwesomeIcons.stethoscope,
    0xe3f3: Icons.local_hospital,
    0xe91f: Icons.medical_services,

    // Default/General icons
    0xf005: FontAwesomeIcons.star,
    0xf004: FontAwesomeIcons.heart,
    0xf0e7: FontAwesomeIcons.bolt,
    0xf06e: FontAwesomeIcons.eye,
    0xf024: FontAwesomeIcons.flag,
    0xf091: FontAwesomeIcons.trophy,
    0xf0a3: FontAwesomeIcons.certificate,
    0xf084: FontAwesomeIcons.key,
  };

  /// Maps icon data from Firebase to appropriate Flutter icon
  static IconData mapIcon({
    int? codePoint,
    String? fontFamily,
    String? fontPackage,
  }) {
    // If no codePoint provided, return default icon
    if (codePoint == null) {
      return Icons.help_outline;
    }

    // Check if we have a mapped icon for this codePoint
    if (_iconMap.containsKey(codePoint)) {
      return _iconMap[codePoint]!;
    }

    // Try to determine icon based on fontFamily
    if (fontFamily == 'MaterialIcons') {
      // Try to create MaterialIcon with the codePoint
      // This might work for standard Material icons
      return IconData(codePoint, fontFamily: fontFamily);
    }

    // For FontAwesome icons that aren't mapped, try common fallbacks
    if (fontFamily == 'FontAwesomeIcons' || fontFamily == 'FontAwesome') {
      // Try to find a similar icon based on codePoint range
      // FontAwesome solid icons typically in 0xf000-0xf8ff range
      if (codePoint >= 0xf000 && codePoint <= 0xf8ff) {
        // Return a generic FontAwesome icon as fallback
        return FontAwesomeIcons.circleQuestion;
      }
    }

    // Default fallback icon
    return Icons.help_outline;
  }

  /// Get icon by name (for custom decks)
  static IconData getIconByName(String name) {
    switch (name.toLowerCase()) {
      // Games
      case 'dice':
        return FontAwesomeIcons.dice;
      case 'gamepad':
        return FontAwesomeIcons.gamepad;
      case 'chess':
        return FontAwesomeIcons.chess;
      case 'puzzle':
        return FontAwesomeIcons.puzzlePiece;
      case 'casino':
        return Icons.casino;

      // Sports
      case 'football':
        return FontAwesomeIcons.football;
      case 'basketball':
        return FontAwesomeIcons.basketballBall;
      case 'baseball':
        return FontAwesomeIcons.baseball;
      case 'soccer':
        return Icons.sports_soccer;
      case 'tennis':
        return Icons.sports_tennis;

      // Entertainment
      case 'music':
        return FontAwesomeIcons.music;
      case 'film':
      case 'movie':
        return FontAwesomeIcons.film;
      case 'tv':
        return FontAwesomeIcons.tv;
      case 'microphone':
      case 'mic':
        return FontAwesomeIcons.microphone;

      // Food
      case 'burger':
        return FontAwesomeIcons.burger;
      case 'pizza':
        return FontAwesomeIcons.pizzaSlice;
      case 'coffee':
        return FontAwesomeIcons.coffee;
      case 'cake':
        return FontAwesomeIcons.cakeCandles;

      // Animals
      case 'dog':
        return FontAwesomeIcons.dog;
      case 'cat':
        return FontAwesomeIcons.cat;
      case 'pets':
        return Icons.pets;

      // Default
      default:
        return Icons.category;
    }
  }
}
