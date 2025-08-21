import React from 'react';
import * as FaIcons from 'react-icons/fa';
import * as MdIcons from 'react-icons/md';
import * as IoIcons from 'react-icons/io5';
import * as BiIcons from 'react-icons/bi';
import * as GiIcons from 'react-icons/gi';
import * as AiIcons from 'react-icons/ai';

export type IconType = React.ComponentType<{ size?: number; color?: string }>;

export interface IconInfo {
  icon: IconType;
  name: string;
  codePoint?: number;
  fontFamily?: string;
}

export interface IconCategory {
  name: string;
  icons: IconInfo[];
}

export const iconCategories: IconCategory[] = [
  {
    name: 'Games',
    icons: [
      { icon: FaIcons.FaDice, name: 'dice', codePoint: 0xf522, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaDiceOne, name: 'diceOne', codePoint: 0xf525, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaDiceTwo, name: 'diceTwo', codePoint: 0xf528, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaDiceThree, name: 'diceThree', codePoint: 0xf527, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaDiceFour, name: 'diceFour', codePoint: 0xf524, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaDiceFive, name: 'diceFive', codePoint: 0xf523, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaDiceSix, name: 'diceSix', codePoint: 0xf526, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaGamepad, name: 'gamepad', codePoint: 0xf11b, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaChess, name: 'chess', codePoint: 0xf439, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaChessKnight, name: 'chessKnight', codePoint: 0xf441, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaChessRook, name: 'chessRook', codePoint: 0xf447, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaPuzzlePiece, name: 'puzzlePiece', codePoint: 0xf12e, fontFamily: 'FontAwesomeIcons' },
      { icon: MdIcons.MdCasino, name: 'casino', codePoint: 0xe14f, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdSportsEsports, name: 'sportsEsports', codePoint: 0xea23, fontFamily: 'MaterialIcons' },
    ],
  },
  {
    name: 'Sports',
    icons: [
      { icon: FaIcons.FaFootballBall, name: 'football', codePoint: 0xf44e, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaBasketballBall, name: 'basketball', codePoint: 0xf434, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaBaseballBall, name: 'baseball', codePoint: 0xf433, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaBowlingBall, name: 'bowlingBall', codePoint: 0xf436, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaGolfBall, name: 'golfBall', codePoint: 0xf450, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaTableTennis, name: 'tableTennis', codePoint: 0xf45d, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaVolleyballBall, name: 'volleyball', codePoint: 0xf45f, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaDumbbell, name: 'dumbbell', codePoint: 0xf44b, fontFamily: 'FontAwesomeIcons' },
      { icon: MdIcons.MdSportsSoccer, name: 'sportsSoccer', codePoint: 0xea1c, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdSportsTennis, name: 'sportsTennis', codePoint: 0xea1e, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdSportsHockey, name: 'sportsHockey', codePoint: 0xea18, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdSportsGolf, name: 'sportsGolf', codePoint: 0xea15, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdFitnessCenter, name: 'fitnessCenter', codePoint: 0xe1b3, fontFamily: 'MaterialIcons' },
    ],
  },
  {
    name: 'Entertainment',
    icons: [
      { icon: FaIcons.FaMusic, name: 'music', codePoint: 0xf001, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaFilm, name: 'film', codePoint: 0xf008, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaTv, name: 'tv', codePoint: 0xf26c, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaMicrophone, name: 'microphone', codePoint: 0xf130, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaGuitar, name: 'guitar', codePoint: 0xf7a6, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaDrum, name: 'drum', codePoint: 0xf569, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaHeadphones, name: 'headphones', codePoint: 0xf025, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaTicketAlt, name: 'ticket', codePoint: 0xf3ff, fontFamily: 'FontAwesomeIcons' },
      { icon: MdIcons.MdMovie, name: 'movie', codePoint: 0xe02c, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdTheaterComedy, name: 'theaterComedy', codePoint: 0xea66, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdMusicNote, name: 'musicNote', codePoint: 0xe3a1, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdMic, name: 'mic', codePoint: 0xe029, fontFamily: 'MaterialIcons' },
    ],
  },
  {
    name: 'Food',
    icons: [
      { icon: FaIcons.FaHamburger, name: 'burger', codePoint: 0xf805, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaPizzaSlice, name: 'pizzaSlice', codePoint: 0xf818, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaIceCream, name: 'iceCream', codePoint: 0xf810, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaCookie, name: 'cookie', codePoint: 0xf563, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaBirthdayCake, name: 'cake', codePoint: 0xf1fd, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaCoffee, name: 'coffee', codePoint: 0xf0f4, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaCocktail, name: 'martiniGlass', codePoint: 0xf561, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaBeer, name: 'beer', codePoint: 0xf0fc, fontFamily: 'FontAwesomeIcons' },
      { icon: MdIcons.MdRestaurant, name: 'restaurant', codePoint: 0xe56c, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdLocalPizza, name: 'localPizza', codePoint: 0xe553, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdCake, name: 'cake', codePoint: 0xe7e9, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdLocalBar, name: 'localBar', codePoint: 0xe540, fontFamily: 'MaterialIcons' },
    ],
  },
  {
    name: 'Animals',
    icons: [
      { icon: FaIcons.FaDog, name: 'dog', codePoint: 0xf6d3, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaCat, name: 'cat', codePoint: 0xf6be, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaHorse, name: 'horse', codePoint: 0xf6f0, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaFish, name: 'fish', codePoint: 0xf578, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaDove, name: 'dove', codePoint: 0xf4ba, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaDragon, name: 'dragon', codePoint: 0xf6d5, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaSpider, name: 'spider', codePoint: 0xf717, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaBug, name: 'bug', codePoint: 0xf188, fontFamily: 'FontAwesomeIcons' },
      { icon: MdIcons.MdPets, name: 'pets', codePoint: 0xe3a9, fontFamily: 'MaterialIcons' },
    ],
  },
  {
    name: 'Nature',
    icons: [
      { icon: FaIcons.FaTree, name: 'tree', codePoint: 0xf1bb, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaLeaf, name: 'leaf', codePoint: 0xf06c, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaSeedling, name: 'seedling', codePoint: 0xf4d8, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaMountain, name: 'mountain', codePoint: 0xf6fc, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaWater, name: 'water', codePoint: 0xf773, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaFire, name: 'fire', codePoint: 0xf06d, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaSun, name: 'sun', codePoint: 0xf185, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaMoon, name: 'moon', codePoint: 0xf186, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaCloud, name: 'cloud', codePoint: 0xf0c2, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaSnowflake, name: 'snowflake', codePoint: 0xf2dc, fontFamily: 'FontAwesomeIcons' },
      { icon: MdIcons.MdPark, name: 'park', codePoint: 0xea63, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdNature, name: 'nature', codePoint: 0xe3a4, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdEco, name: 'eco', codePoint: 0xea35, fontFamily: 'MaterialIcons' },
    ],
  },
  {
    name: 'Objects',
    icons: [
      { icon: FaIcons.FaStar, name: 'solidStar', codePoint: 0xf005, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaHeart, name: 'heart', codePoint: 0xf004, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaGem, name: 'gem', codePoint: 0xf3a5, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaCrown, name: 'crown', codePoint: 0xf521, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaTrophy, name: 'trophy', codePoint: 0xf091, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaMedal, name: 'medal', codePoint: 0xf5a2, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaGift, name: 'gift', codePoint: 0xf06b, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaBell, name: 'bell', codePoint: 0xf0f3, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaLightbulb, name: 'lightbulb', codePoint: 0xf0eb, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaKey, name: 'key', codePoint: 0xf084, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaLock, name: 'lock', codePoint: 0xf023, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaMagnet, name: 'magnet', codePoint: 0xf076, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaCompass, name: 'compass', codePoint: 0xf14e, fontFamily: 'FontAwesomeIcons' },
      { icon: MdIcons.MdStar, name: 'star', codePoint: 0xe838, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdFavorite, name: 'favorite', codePoint: 0xe87d, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdEmojiEvents, name: 'emojiEvents', codePoint: 0xea23, fontFamily: 'MaterialIcons' },
    ],
  },
  {
    name: 'Tech',
    icons: [
      { icon: FaIcons.FaLaptop, name: 'laptop', codePoint: 0xf109, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaMobileAlt, name: 'mobile', codePoint: 0xf3cd, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaDesktop, name: 'desktop', codePoint: 0xf108, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaKeyboard, name: 'keyboard', codePoint: 0xf11c, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaRobot, name: 'robot', codePoint: 0xf544, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaMicrochip, name: 'microchip', codePoint: 0xf2db, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaWifi, name: 'wifi', codePoint: 0xf1eb, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaBluetooth, name: 'bluetooth', codePoint: 0xf293, fontFamily: 'FontAwesomeIcons' },
      { icon: MdIcons.MdComputer, name: 'computer', codePoint: 0xe30a, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdPhoneAndroid, name: 'phoneAndroid', codePoint: 0xe324, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdSmartToy, name: 'smartToy', codePoint: 0xf1d6, fontFamily: 'MaterialIcons' },
    ],
  },
  {
    name: 'Education',
    icons: [
      { icon: FaIcons.FaBook, name: 'book', codePoint: 0xf02d, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaGraduationCap, name: 'graduationCap', codePoint: 0xf19d, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaPencilAlt, name: 'pencil', codePoint: 0xf303, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaRuler, name: 'ruler', codePoint: 0xf545, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaCalculator, name: 'calculator', codePoint: 0xf1ec, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaMicroscope, name: 'microscope', codePoint: 0xf610, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaAtom, name: 'atom', codePoint: 0xf5d2, fontFamily: 'FontAwesomeIcons' },
      { icon: MdIcons.MdSchool, name: 'school', codePoint: 0xe80c, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdScience, name: 'science', codePoint: 0xea4b, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdPsychology, name: 'psychology', codePoint: 0xea4a, fontFamily: 'MaterialIcons' },
    ],
  },
  {
    name: 'Travel',
    icons: [
      { icon: FaIcons.FaPlane, name: 'plane', codePoint: 0xf072, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaCar, name: 'car', codePoint: 0xf1b9, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaTrain, name: 'train', codePoint: 0xf238, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaShip, name: 'ship', codePoint: 0xf21a, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaRocket, name: 'rocket', codePoint: 0xf135, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaBicycle, name: 'bicycle', codePoint: 0xf206, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaMotorcycle, name: 'motorcycle', codePoint: 0xf21c, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaHelicopter, name: 'helicopter', codePoint: 0xf533, fontFamily: 'FontAwesomeIcons' },
      { icon: MdIcons.MdFlight, name: 'flight', codePoint: 0xe539, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdDirectionsCar, name: 'directionsCar', codePoint: 0xe531, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdDirectionsBoat, name: 'directionsBoat', codePoint: 0xe532, fontFamily: 'MaterialIcons' },
    ],
  },
  {
    name: 'Misc',
    icons: [
      { icon: FaIcons.FaFlag, name: 'flag', codePoint: 0xf024, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaMapPin, name: 'mapPin', codePoint: 0xf276, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaGlobe, name: 'globe', codePoint: 0xf0ac, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaLanguage, name: 'language', codePoint: 0xf1ab, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaPalette, name: 'palette', codePoint: 0xf53f, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaBrush, name: 'brush', codePoint: 0xf55d, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaCamera, name: 'camera', codePoint: 0xf030, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaImage, name: 'image', codePoint: 0xf03e, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaMagic, name: 'wandMagicSparkles', codePoint: 0xf0d0, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaBolt, name: 'bolt', codePoint: 0xf0e7, fontFamily: 'FontAwesomeIcons' },
      { icon: FaIcons.FaSnowman, name: 'snowman', codePoint: 0xf7d0, fontFamily: 'FontAwesomeIcons' },
      { icon: MdIcons.MdFlag, name: 'flag', codePoint: 0xe153, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdPublic, name: 'public', codePoint: 0xe80b, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdPalette, name: 'palette', codePoint: 0xe40a, fontFamily: 'MaterialIcons' },
      { icon: MdIcons.MdAutoAwesome, name: 'autoAwesome', codePoint: 0xe65f, fontFamily: 'MaterialIcons' },
    ],
  },
];

export const getAllIcons = (): IconInfo[] => {
  return iconCategories.flatMap(category => category.icons);
};
