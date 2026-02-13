//
//  DataService.swift
//  BoxOfficer
//
//  Unified data service layer. Acts as the single point of contact for all
//  external data fetching. In production, this would proxy through Firebase
//  Cloud Functions to keep API keys server-side.
//

import Foundation

/// `DataService` is the single source of truth for all movie data.
/// It abstracts away whether data comes from TMDB, Trakt, OMDb, or Firebase/Firestore.
/// Future: Route calls through Firebase Cloud Functions for full server-side key protection.
final class DataService {
    static let shared = DataService()

    private let tmdb = TMDBService.shared
    private let trakt = TraktService.shared

    private init() {}

    // MARK: - Now Playing / In Theaters

    func fetchNowPlayingMovies() async throws -> [TMDBMovie] {
        return try await tmdb.fetchNowPlayingMovies()
    }

    func fetchInTheatersTheatrical() async throws -> [TMDBMovie] {
        return try await tmdb.fetchInTheatersTheatrical()
    }

    // MARK: - Trending

    func fetchTrendingMoviesTMDB() async throws -> [TMDBMovie] {
        return try await tmdb.fetchTrendingMovies()
    }

    func fetchTrendingMoviesTrakt() async throws -> [TMDBMovie] {
        return try await trakt.fetchTrendingMovies()
    }

    // MARK: - Discovery

    func fetchDigitalReleases() async throws -> [TMDBMovie] {
        return try await tmdb.fetchDigitalReleases()
    }

    func fetchUpcomingTheatrical() async throws -> [TMDBMovie] {
        return try await tmdb.fetchUpcomingTheatrical()
    }

    func fetchUpcomingDigital() async throws -> [TMDBMovie] {
        return try await tmdb.fetchUpcomingDigital()
    }

    func fetchTopRated(region: String?, pages: Int) async throws -> [TMDBMovie] {
        return try await tmdb.fetchTopRated(region: region, pages: pages)
    }

    func fetchTopGrossing(pages: Int) async throws -> [TMDBMovie] {
        return try await tmdb.fetchTopGrossing(pages: pages)
    }

    // MARK: - Search

    func searchMovies(query: String) async throws -> [TMDBMovie] {
        return try await tmdb.searchMovies(query: query)
    }

    // MARK: - Movie Details

    func fetchMovieDetails(id: Int) async throws -> TMDBMovieDetails {
        return try await tmdb.fetchMovieDetails(id: id)
    }

    func fetchMovieCredits(id: Int) async throws -> TMDBCredits {
        return try await tmdb.fetchMovieCredits(id: id)
    }

    func fetchWatchProviders(id: Int) async throws -> TMDBWatchProviderRegion? {
        return try await tmdb.fetchWatchProviders(id: id)
    }

    // MARK: - External IDs

    func fetchPersonExternalIDs(id: Int) async throws -> TMDBPersonExternalIDs {
        return try await tmdb.fetchPersonExternalIDs(id: id)
    }

    func fetchMovieExternalIDs(id: Int) async throws -> TMDBMovieExternalIDs {
        return try await tmdb.fetchMovieExternalIDs(id: id)
    }

    // MARK: - Rotten Tomatoes / OMDb

    func fetchRottenTomatoesScore(imdbID: String) async throws -> Int? {
        return try await tmdb.fetchRottenTomatoesScore(imdbID: imdbID)
    }

    func fetchOMDbMovieDetails(imdbID: String) async throws -> OMDbResponse? {
        return try await tmdb.fetchOMDbMovieDetails(imdbID: imdbID)
    }
}
