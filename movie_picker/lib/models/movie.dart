class Movie {
  final int id;
  final String title;
  final String description;
  final String posterUrl;
  final String genre;
  final String subgenre;
  final String releaseDate;
  final double voteAverage;
  final String language;
  final List<String> keywords;
  final bool adult; // New field to track adult content

  const Movie({
    required this.id,
    required this.title,
    required this.description,
    required this.posterUrl,
    required this.genre,
    required this.subgenre,
    required this.releaseDate,
    required this.voteAverage,
    required this.language,
    this.keywords = const [],
    this.adult = false, // Default to false for safety
  });

  String get displayTitle => '$title ($releaseDate)';

  String get uniqueSubgenre => subgenre == genre ? '' : subgenre;

  String get formattedScore => voteAverage.toStringAsFixed(1);

  // Create a copy of the movie with updated keywords
  Movie copyWith({
    int? id,
    String? title,
    String? description,
    String? posterUrl,
    String? genre,
    String? subgenre,
    String? releaseDate,
    double? voteAverage,
    String? language,
    List<String>? keywords,
    bool? adult,
  }) {
    return Movie(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      posterUrl: posterUrl ?? this.posterUrl,
      genre: genre ?? this.genre,
      subgenre: subgenre ?? this.subgenre,
      releaseDate: releaseDate ?? this.releaseDate,
      voteAverage: voteAverage ?? this.voteAverage,
      language: language ?? this.language,
      keywords: keywords ?? this.keywords,
      adult: adult ?? this.adult,
    );
  }

  // Sample movie list
  static const List<Movie> sampleMovies = [
    Movie(
      id: 1,
      title: "The Shawshank Redemption",
      description:
          "Two imprisoned men bond over a number of years, finding solace and eventual redemption through acts of common decency.",
      posterUrl:
          "https://image.tmdb.org/t/p/w500/q6y0Go1tsGEsmtFryDOJo3dEmqu.jpg",
      genre: "Drama",
      subgenre: "Crime",
      releaseDate: "1994",
      voteAverage: 8.7,
      language: "en",
      adult: false,
      keywords: [
        "prison",
        "friendship",
        "hope",
        "redemption",
        "escape",
        "corruption",
        "justice",
      ],
    ),
    Movie(
      id: 2,
      title: "The Dark Knight",
      description:
          "When the menace known as the Joker wreaks havoc and chaos on the people of Gotham, Batman must accept one of the greatest psychological and physical tests of his ability to fight injustice.",
      posterUrl:
          "https://image.tmdb.org/t/p/w500/qJ2tW6WMUDux911r6m7haRef0WH.jpg",
      genre: "Action",
      subgenre: "Crime",
      releaseDate: "2008",
      voteAverage: 8.5,
      language: "en",
      adult: false,
      keywords: [
        "superhero",
        "vigilante",
        "chaos",
        "joker",
        "batman",
        "gotham",
        "crime",
        "psychological",
      ],
    ),
    Movie(
      id: 3,
      title: "Pulp Fiction",
      description:
          "The lives of two mob hitmen, a boxer, a gangster and his wife, and a pair of diner bandits intertwine in four tales of violence and redemption.",
      posterUrl:
          "https://image.tmdb.org/t/p/w500/d5iIlFn5s0ImszYzBPb8JPIfbXD.jpg",
      genre: "Crime",
      subgenre: "Drama",
      releaseDate: "1994",
      voteAverage: 8.9,
      language: "en",
      adult: false,
      keywords: [
        "nonlinear",
        "hitman",
        "violence",
        "dialogue",
        "tarantino",
        "crime",
        "redemption",
      ],
    ),
    Movie(
      id: 4,
      title: "The Hangover",
      description:
          "Three buddies wake up from a bachelor party in Las Vegas, with no memory of the previous night and the bachelor missing. They make their way around the city in order to find their friend before his wedding.",
      posterUrl:
          "https://image.tmdb.org/t/p/w500/uluhlXubGu1VxU63X9VHCLcD6Q6.jpg",
      genre: "Comedy",
      subgenre: "Adventure",
      releaseDate: "2009",
      voteAverage: 7.7,
      language: "en",
      adult: false,
      keywords: [
        "bachelor party",
        "las vegas",
        "memory loss",
        "friendship",
        "comedy",
        "wedding",
        "adventure",
      ],
    ),
    Movie(
      id: 5,
      title: "Inception",
      description:
          "A thief who steals corporate secrets through dream-sharing technology is given the inverse task of planting an idea into the mind of a C.E.O.",
      posterUrl:
          "https://image.tmdb.org/t/p/w500/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg",
      genre: "Sci-Fi",
      subgenre: "Action",
      releaseDate: "2010",
      voteAverage: 8.8,
      language: "en",
      adult: false,
      keywords: [
        "dreams",
        "reality",
        "heist",
        "mind",
        "layers",
        "subconscious",
        "nolan",
        "complex",
      ],
    ),
    Movie(
      id: 6,
      title: "The Matrix",
      description:
          "A computer hacker learns from mysterious rebels about the true nature of his reality and his role in the war against its controllers.",
      posterUrl:
          "https://image.tmdb.org/t/p/w500/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg",
      genre: "Sci-Fi",
      subgenre: "Action",
      releaseDate: "1999",
      voteAverage: 8.7,
      language: "en",
      adult: false,
      keywords: [
        "virtual reality",
        "hacker",
        "simulation",
        "philosophy",
        "action",
        "cyberpunk",
        "chosen one",
      ],
    ),
    Movie(
      id: 7,
      title: "Forrest Gump",
      description:
          "The presidencies of Kennedy and Johnson, the Vietnam War, the Watergate scandal and other historical events unfold from the perspective of an Alabama man with an IQ of 75.",
      posterUrl:
          "https://image.tmdb.org/t/p/w500/arw2vcBveWOVZrFpxxaqdtQpgq.jpg",
      genre: "Drama",
      subgenre: "Romance",
      releaseDate: "1994",
      voteAverage: 8.8,
      language: "en",
      adult: false,
      keywords: [
        "life story",
        "historical",
        "vietnam war",
        "love",
        "destiny",
        "simple man",
        "america",
      ],
    ),
    Movie(
      id: 8,
      title: "The Lord of the Rings: The Fellowship of the Ring",
      description:
          "A meek Hobbit from the Shire and eight companions set out on a journey to destroy the powerful One Ring and save Middle-earth from the Dark Lord Sauron.",
      posterUrl:
          "https://image.tmdb.org/t/p/w500/6oom5QYQ2yQTMJIbnvbkBL9cHo6.jpg",
      genre: "Fantasy",
      subgenre: "Adventure",
      releaseDate: "2001",
      voteAverage: 8.8,
      language: "en",
      adult: false,
      keywords: [
        "fantasy",
        "epic",
        "quest",
        "magic",
        "friendship",
        "good vs evil",
        "tolkien",
        "middle earth",
      ],
    ),
    Movie(
      id: 9,
      title: "The Silence of the Lambs",
      description:
          "A young F.B.I. cadet must receive the help of an incarcerated and manipulative cannibal killer to help catch another serial killer, a madman who skins his victims.",
      posterUrl:
          "https://image.tmdb.org/t/p/w500/rplLJ2hPcOQmkFhTqUte0MkEaO2.jpg",
      genre: "Thriller",
      subgenre: "Crime",
      releaseDate: "1991",
      voteAverage: 8.6,
      language: "en",
      adult: false,
      keywords: [
        "serial killer",
        "fbi",
        "psychological",
        "cannibal",
        "investigation",
        "thriller",
        "hannibal",
      ],
    ),
    Movie(
      id: 10,
      title: "Spirited Away",
      description:
          "During her family's move to the suburbs, a sullen 10-year-old girl wanders into a world ruled by gods, witches, and spirits, and where humans are changed into beasts.",
      posterUrl:
          "https://image.tmdb.org/t/p/w500/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg",
      genre: "Animation",
      subgenre: "Fantasy",
      releaseDate: "2001",
      voteAverage: 8.6,
      language: "en",
      adult: false,
      keywords: [
        "animation",
        "studio ghibli",
        "spirits",
        "magic",
        "coming of age",
        "japanese",
        "fantasy",
      ],
    ),
    Movie(
      id: 11,
      title: "The Grand Budapest Hotel",
      description:
          "The adventures of Gustave H, a legendary concierge at a famous hotel from the fictional Republic of Zubrowka between the first and second World Wars.",
      posterUrl:
          "https://image.tmdb.org/t/p/w500/eWdyYQreja6JGCzqHWXpWHDrrOc.jpg",
      genre: "Comedy",
      subgenre: "Drama",
      releaseDate: "2014",
      voteAverage: 8.1,
      language: "en",
      adult: false,
      keywords: [
        "wes anderson",
        "hotel",
        "concierge",
        "quirky",
        "visual style",
        "comedy",
        "european",
      ],
    ),
    Movie(
      id: 12,
      title: "Parasite",
      description:
          "All unemployed, Ki-taek and his family take peculiar interest in the wealthy and glamorous Parks, as they ingratiate themselves into their lives and get entangled in an unexpected incident.",
      posterUrl:
          "https://image.tmdb.org/t/p/w500/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg",
      genre: "Thriller",
      subgenre: "Drama",
      releaseDate: "2019",
      voteAverage: 8.6,
      language: "en",
      adult: false,
      keywords: [
        "class struggle",
        "social commentary",
        "korean",
        "dark comedy",
        "family",
        "deception",
        "inequality",
      ],
    ),
    Movie(
      id: 13,
      title: "The Lion King",
      description:
          "Lion prince Simba and his father are targeted by his bitter uncle, who wants to ascend the throne himself.",
      posterUrl:
          "https://image.tmdb.org/t/p/w500/sKCr78MXSLixwmZ8DyJLrpMsd15.jpg",
      genre: "Animation",
      subgenre: "Drama",
      releaseDate: "1994",
      voteAverage: 8.5,
      language: "en",
      adult: false,
      keywords: [
        "disney",
        "animation",
        "coming of age",
        "family",
        "africa",
        "animals",
        "musical",
        "responsibility",
      ],
    ),
    Movie(
      id: 14,
      title: "The Shining",
      description:
          "A family heads to an isolated hotel for the winter where a sinister presence influences the father into violence, while his psychic son sees horrific forebodings from both past and future.",
      posterUrl:
          "https://image.tmdb.org/t/p/w500/b6ko0IKC8MdYBBPkkA1aBPLe2yz.jpg",
      genre: "Horror",
      subgenre: "Drama",
      releaseDate: "1980",
      voteAverage: 8.4,
      language: "en",
      adult: false,
      keywords: [
        "horror",
        "psychological",
        "isolation",
        "kubrick",
        "hotel",
        "madness",
        "supernatural",
        "family",
      ],
    ),
    Movie(
      id: 15,
      title: "La La Land",
      description:
          "A jazz pianist falls for an aspiring actress in Los Angeles.",
      posterUrl:
          "https://image.tmdb.org/t/p/w500/uDO8zWDhfWwoFdKS4fzkUJt0Rf0.jpg",
      genre: "Romance",
      subgenre: "Musical",
      releaseDate: "2016",
      voteAverage: 8.4,
      language: "en",
      adult: false,
      keywords: [
        "musical",
        "romance",
        "jazz",
        "los angeles",
        "dreams",
        "ambition",
        "love",
        "artistic",
      ],
    ),
  ];
}
