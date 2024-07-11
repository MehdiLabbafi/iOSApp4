//
//  SearchResult.swift
//  SuperTunes
//
//  Created by Mehdi Labbafi on 2024-07-03.
//


import UIKit

import AVFoundation

class SuperTunes: UIViewController {
    
    var searchResults = [SearchResult]() // Array to hold search results
    var hasSearched = false // Flag to check if search has been performed
    var isLoading = false // Flag to indicate if data is being loaded
    var player: AVPlayer? // Add this property for audio playback

    @IBOutlet weak var searchBar: UISearchBar! // Outlet for search bar
    @IBOutlet weak var tableView: UITableView! // Outlet for table view
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Additional setup after loading the view.
        tableView.contentInset = UIEdgeInsets(top: 51, left: 0, bottom: 0, right: 0) // Set table view content inset
        let cellNib1 = UINib(nibName: TableView.CellIdentifiers.ResultCell, bundle: nil)
        tableView.register(cellNib1, forCellReuseIdentifier: TableView.CellIdentifiers.ResultCell) // Register ResultCell nib
        let cellNib2 = UINib(nibName: TableView.CellIdentifiers.loadingCell, bundle: nil)
        tableView.register(cellNib2, forCellReuseIdentifier: TableView.CellIdentifiers.loadingCell) // Register LoadingCell nib

        tableView.dataSource = self
        tableView.delegate = self
        searchBar.delegate = self
    }

    struct TableView {
        struct CellIdentifiers {
            static let ResultCell = "ResultCell" // Identifier for ResultCell
            static let loadingCell = "LoadingCell" // Identifier for LoadingCell
        }
    }
    
    // MARK: - Helper Methods
    func iTunesURL(searchText: String) -> URL {
        let encodedText = searchText.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)! // Encode search text
        let urlString = String(format: "https://itunes.apple.com/search?term=%@&limit=200", encodedText) // Create URL string
        let url = URL(string: urlString)
        return url! // Return URL
    }

    func performStoreRequest(with url: URL) -> Data? {
        do {
            return try Data(contentsOf: url) // Try to get data from URL
        } catch {
            print("Download Error: \(error.localizedDescription)")
            showNetworkError() // Show network error if data download fails
            return nil
        }
    }

    func parse(data: Data) -> [SearchResult] {
        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode(ResultArray.self, from: data) // Decode JSON data
            let uniqueResults = filterUniqueResults(results: result.results)
            return uniqueResults
        } catch {
            print("JSON Error: \(error)")
            return []
        }
    }
    
    func filterUniqueResults(results: [SearchResult]) -> [SearchResult] {
        var seen = Set<String>()
        var uniqueResults = [SearchResult]()
        
        for result in results {
            let identifier = "\(result.artist)-\(result.type)-\(String(describing: result.trackName))"
            if !seen.contains(identifier) {
                seen.insert(identifier)
                uniqueResults.append(result)
            }
        }
        return uniqueResults
    }

    func showNetworkError() {
        let alert = UIAlertController(
            title: "Whoops...",
            message: "There was an error accessing the iTunes Store. Please try again.",
            preferredStyle: .alert)
        
        let action = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(action)
        
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func playAudio(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.play()
    }
}

// MARK: - Table View Delegate
extension SuperTunes: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isLoading {
            return 1 // Show one row for the loading cell
        } else if hasSearched && searchResults.isEmpty {
            return 1 // Show one row for the "Nothing found" cell
        } else {
            return searchResults.count // Return the number of search results
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isLoading {
            let cell = tableView.dequeueReusableCell(withIdentifier: TableView.CellIdentifiers.loadingCell, for: indexPath)
            let spinner = cell.viewWithTag(100) as! UIActivityIndicatorView
            spinner.startAnimating() // Start the spinner animation
            return cell
        } else if searchResults.isEmpty && hasSearched {
            let cell = tableView.dequeueReusableCell(withIdentifier: TableView.CellIdentifiers.ResultCell, for: indexPath) as! ResultCell
            cell.nameLabel.text = "(Nothing found)"
            cell.artistNameLabel.text = ""
            cell.artworkImageView.image = nil
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: TableView.CellIdentifiers.ResultCell, for: indexPath) as! ResultCell
            let searchResult = searchResults[indexPath.row]
            cell.nameLabel.text = searchResult.trackName
            if searchResult.artist.isEmpty {
                cell.artistNameLabel.text = "Unknown"
            } else {
                cell.artistNameLabel.text = String(format: "%@ (%@)", searchResult.artist, searchResult.type)
            }
            cell.artworkImageView.image = UIImage(systemName: "square") // Placeholder image
            if let url = URL(string: searchResult.imageSmall) {
                loadArtworkImage(url: url, for: cell)
            }
            return cell
        }
    }
    
    func loadArtworkImage(url: URL, for cell: ResultCell) {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    cell.artworkImageView.image = image // Update the image view with the downloaded image
                }
            }
        }
        task.resume() // Start the data task
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        tableView.deselectRow(at: indexPath, animated: true) // Deselect the row after selection
        let searchResult = searchResults[indexPath.row]
        if let previewUrlString = searchResult.previewUrl, let previewUrl = URL(string: previewUrlString) {
            playAudio(url: previewUrl) // Play the audio preview
        }
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if searchResults.isEmpty || isLoading {
            return nil // Prevent row selection if loading or no results
        } else {
            return indexPath
        }
    }
}

// MARK: - UIBarPositioningDelegate
extension SuperTunes: UIBarPositioningDelegate {
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}

// MARK: - Search Bar Delegate
extension SuperTunes: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if !searchBar.text!.isEmpty {
            searchBar.resignFirstResponder() // Dismiss the keyboard
            isLoading = true
            tableView.reloadData() // Reload table view to show loading spinner
            hasSearched = true
            searchResults = []
            
            let queue = DispatchQueue.global()
            let url = self.iTunesURL(searchText: searchBar.text!)
            queue.async { // Perform network request on background thread
                if let data = self.performStoreRequest(with: url) {
                    self.searchResults = self.parse(data: data)
                    self.searchResults.sort(by: <)
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.tableView.reloadData() // Reload table view with search results
                    }
                    return
                }
            }
        }
    }
}

func < (lhs: SearchResult, rhs: SearchResult) -> Bool {
    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
}
