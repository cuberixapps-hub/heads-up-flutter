import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/deck.dart';
import '../providers/deck_provider.dart';
import '../services/haptic_service.dart';
import 'deck_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final HapticService _hapticService = HapticService();
  
  List<Deck> _filteredDecks = [];
  bool _isSearching = false;
  late AnimationController _animationController;
  
  static const searchColor = Color(0xFF9B59B6);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Auto-focus search field after animation
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _searchFocusNode.requestFocus();
        _animationController.forward();
      }
    });
    
    _searchController.addListener(_onSearchChanged);
    
    // Initialize with all decks
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final deckProvider = Provider.of<DeckProvider>(context, listen: false);
      setState(() {
        _filteredDecks = deckProvider.allDecks;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);
    
    setState(() {
      _isSearching = query.isNotEmpty;
      
      if (query.isEmpty) {
        _filteredDecks = deckProvider.allDecks;
      } else {
        _filteredDecks = deckProvider.allDecks.where((deck) {
          // Search in name, description, tags, and cards
          final nameMatch = deck.name.toLowerCase().contains(query);
          final descriptionMatch = deck.description.toLowerCase().contains(query);
          final tagsMatch = deck.tags.any((tag) => tag.toLowerCase().contains(query));
          final cardsMatch = deck.cards.any((card) => card.toLowerCase().contains(query));
          
          return nameMatch || descriptionMatch || tagsMatch || cardsMatch;
        }).toList();
      }
    });
  }

  void _clearSearch() {
    _hapticService.lightImpact();
    _searchController.clear();
    _searchFocusNode.requestFocus();
  }

  void _closeSearch() {
    _hapticService.lightImpact();
    Navigator.of(context).pop();
  }

  void _navigateToDeckDetails(Deck deck) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeckDetailsScreen(
          deck: deck,
          heroTag: 'search_deck_${deck.id}',
          onPlay: () {
            // Navigate back to home and play the deck
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  searchColor.withOpacity(0.15),
                  Colors.black,
                  Colors.black,
                ],
              ),
            ),
          ),
          
          // Content
          SafeArea(
            child: Column(
              children: [
                // Search bar header
                _buildSearchHeader(),
                
                // Search results
                Expanded(
                  child: _buildSearchResults(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Back button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _closeSearch,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white.withOpacity(0.9),
                  size: 24,
                ),
              ),
            ),
          )
          .animate()
          .fadeIn(delay: 100.ms, duration: 300.ms)
          .slideX(begin: -0.3, end: 0, duration: 400.ms, curve: Curves.easeOut),
          
          const SizedBox(width: 8),
          
          // Search input field with Hero transition
          Expanded(
            child: Hero(
              tag: 'search_chip',
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        searchColor.withOpacity(0.25),
                        searchColor.withOpacity(0.15),
                      ],
                    ),
                    border: Border.all(
                      color: searchColor.withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: searchColor.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Search icon
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 12),
                        child: ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              searchColor.withOpacity(0.9),
                              searchColor.withOpacity(0.6),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Icon(
                            Icons.search_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      
                      // Text field
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search decks, cards, tags...',
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                          cursorColor: searchColor,
                        ),
                      ),
                      
                      // Clear button
                      if (_searchController.text.isNotEmpty)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _clearSearch,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white.withOpacity(0.7),
                                size: 20,
                              ),
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 200.ms)
                        .scale(begin: const Offset(0.5, 0.5), duration: 200.ms),
                      
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (!_isSearching && _searchController.text.isEmpty) {
      // Show search suggestions
      return _buildSearchSuggestions();
    }
    
    if (_filteredDecks.isEmpty) {
      // No results found
      return _buildNoResults();
    }
    
    // Show filtered results
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: _filteredDecks.length,
      itemBuilder: (context, index) {
        final deck = _filteredDecks[index];
        return _buildDeckCard(deck, index);
      },
    );
  }

  Widget _buildSearchSuggestions() {
    final suggestions = [
      {'icon': FontAwesomeIcons.fire, 'text': 'Trending', 'color': const Color(0xFFE74C3C)},
      {'icon': FontAwesomeIcons.film, 'text': 'Movies', 'color': const Color(0xFFE67E22)},
      {'icon': FontAwesomeIcons.music, 'text': 'Music', 'color': const Color(0xFFF39C12)},
      {'icon': FontAwesomeIcons.gamepad, 'text': 'Gaming', 'color': const Color(0xFF9B59B6)},
      {'icon': FontAwesomeIcons.globe, 'text': 'World', 'color': const Color(0xFF3498DB)},
      {'icon': FontAwesomeIcons.heart, 'text': 'Love & Romance', 'color': const Color(0xFFE91E63)},
    ];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Popular Categories',
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.9),
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          )
          .animate()
          .fadeIn(delay: 200.ms, duration: 400.ms)
          .slideY(begin: 0.3, end: 0, duration: 400.ms),
          
          const SizedBox(height: 8),
          
          Text(
            'Tap to explore',
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          )
          .animate()
          .fadeIn(delay: 300.ms, duration: 400.ms),
          
          const SizedBox(height: 24),
          
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: suggestions.asMap().entries.map((entry) {
              final index = entry.key;
              final suggestion = entry.value;
              
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _hapticService.selection();
                    _searchController.text = suggestion['text'] as String;
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          (suggestion['color'] as Color).withOpacity(0.2),
                          (suggestion['color'] as Color).withOpacity(0.1),
                        ],
                      ),
                      border: Border.all(
                        color: (suggestion['color'] as Color).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaIcon(
                          suggestion['icon'] as IconData,
                          color: suggestion['color'] as Color,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          suggestion['text'] as String,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(
                delay: (300 + index * 50).ms,
                duration: 400.ms,
              )
              .scale(
                begin: const Offset(0.8, 0.8),
                delay: (300 + index * 50).ms,
                duration: 400.ms,
                curve: Curves.easeOutBack,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  searchColor.withOpacity(0.2),
                  searchColor.withOpacity(0.05),
                ],
              ),
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 64,
              color: searchColor.withOpacity(0.6),
            ),
          )
          .animate()
          .fadeIn(duration: 400.ms)
          .scale(begin: const Offset(0.5, 0.5), duration: 500.ms, curve: Curves.easeOutBack),
          
          const SizedBox(height: 24),
          
          Text(
            'No results found',
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.9),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          )
          .animate()
          .fadeIn(delay: 200.ms, duration: 400.ms)
          .slideY(begin: 0.3, end: 0, delay: 200.ms, duration: 400.ms),
          
          const SizedBox(height: 8),
          
          Text(
            'Try searching for something else',
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          )
          .animate()
          .fadeIn(delay: 300.ms, duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildDeckCard(Deck deck, int index) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _hapticService.selection();
          _navigateToDeckDetails(deck);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                deck.color.withOpacity(0.2),
                deck.color.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: deck.color.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: deck.color.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Deck icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      deck.color.withOpacity(0.3),
                      deck.color.withOpacity(0.15),
                    ],
                  ),
                ),
                child: Icon(
                  deck.icon,
                  color: deck.color,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Deck info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            deck.name,
                            style: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
                        // Premium badge
                        if (deck.isPremium)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFD700),
                                  Color(0xFFFFA500),
                                ],
                              ),
                            ),
                            child: Text(
                              'PRO',
                              style: GoogleFonts.poppins(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Text(
                      deck.description,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Cards count
                    Row(
                      children: [
                        Icon(
                          Icons.style_rounded,
                          size: 14,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${deck.cards.length} cards',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Arrow icon
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: deck.color.withOpacity(0.6),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    )
    .animate()
    .fadeIn(
      delay: (100 + index * 50).ms,
      duration: 400.ms,
    )
    .slideX(
      begin: 0.2,
      end: 0,
      delay: (100 + index * 50).ms,
      duration: 400.ms,
      curve: Curves.easeOut,
    );
  }
}

