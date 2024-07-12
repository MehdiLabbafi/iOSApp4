//
//  SuperTunes.swift
//  SuperTunes
//
//  Created by Mehdi Labbafi on 2024-07-03.
//

import UIKit // Import UIKit framework for UI components
import AVFoundation // Import AVFoundation framework for audio playback

class SuperTunes: UIViewController { // SuperTunes class inheriting from UIViewController
    
    var searchResults = [SearchResult]() // Array to hold search results
    var hasSearched = false // Flag to check if search has been performed
    var isLoading = false // Flag to indicate if data is being loaded
    var player: AVPlayer? // Property for audio playback

    @IBOutlet weak var searchBar: UISearchBar! // Outlet for search bar
    @IBOutlet weak var tableView: UITableView! // Outlet for table view
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Additional setup after loading the view.
        tableView.contentInset = UIEdgeInsets(top: 51, left: 0, bottom: 0, right: 0) // Set table view content inset to avoid overlapping with search bar
        let cellNib1 = UINib(nibName: TableView.CellIdentifiers.ResultCell, bundle: nil) // Create nib object for ResultCell
        tableView.register(cellNib1, forCellReuseIdentifier: TableView.CellIdentifiers.ResultCell) // Register ResultCell nib with table view
        let cellNib2 = UINib(nibName: TableView.CellIdentifiers.loadingCell, bundle: nil) // Create nib object for LoadingCell
        tableView.register(cellNib2, forCellReuseIdentifier: TableView.CellIdentifiers.loadingCell) // Register LoadingCell nib with table view

        tableView.dataSource = self // Set data source for table view
        tableView.delegate = self // Set delegate for table view
        searchBar.delegate = self // Set delegate for search bar
    }

    struct TableView {
        struct CellIdentifiers {
            static let ResultCell = "ResultCell" // Identifier for ResultCell
            static let loadingCell = "LoadingCell" // Identifier for LoadingCell
        }
    }
    
    // MARK: - Helper Methods
    func iTunesURL(searchText: String) -> URL {
        let encodedText = searchText.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)! // Encode search text to make it URL-safe
        let urlString = String(format: "https://itunes.apple.com/search?term=%@&limit=200", encodedText) // Create URL string with encoded search text and limit of 200 results
        let url = URL(string: urlString) // Create URL object from string
        return url! // Return URL
    }

    func performStoreRequest(with url: URL) -> Data? {
        do {
            return try Data(contentsOf: url) // Try to get data from URL
        } catch {
            print("Download Error: \(error.localizedDescription)") // Print error message if data download fails
            showNetworkError() // Show network error alert
            return nil // Return nil if data download fails
        }
    }

    func parse(data: Data) -> [SearchResult] {
        do {
            let decoder = JSONDecoder() // Create JSONDecoder object
            let result = try decoder.decode(ResultArray.self, from: data) // Decode JSON data into ResultArray
            let uniqueResults = filterUniqueResults(results: result.results) // Filter unique results
            return uniqueResults // Return unique results
        } catch {
            print("JSON Error: \(error)") // Print error message if JSON decoding fails
            return [] // Return empty array if JSON decoding fails
        }
    }
    
    func filterUniqueResults(results: [SearchResult]) -> [SearchResult] {
        var seen = Set<String>() // Create a set to track seen results
        var uniqueResults = [SearchResult]() // Create an array to hold unique results
        
        for result in results {
            let identifier = "\(result.artist)-\(result.type)-\(String(describing: result.trackName))" // Create a unique identifier for each result
            if !seen.contains(identifier) { // Check if the identifier is already seen
                seen.insert(identifier) // Add identifier to seen set
                uniqueResults.append(result) // Add result to uniqueResults array
            }
        }
        return uniqueResults // Return unique results
    }

    func showNetworkError() {
        let alert = UIAlertController(
            title: "Whoops...", // Alert title
            message: "There was an error accessing the iTunes Store. Please try again.", // Alert message
            preferredStyle: .alert) // Alert style
        
        let action = UIAlertAction(title: "OK", style: .default, handler: nil) // OK action for the alert
        alert.addAction(action) // Add OK action to the alert
        
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil) // Present the alert on the main thread
        }
    }
    
    func playAudio(url: URL) {
        let playerItem = AVPlayerItem(url: url) // Create AVPlayerItem with URL
        player = AVPlayer(playerItem: playerItem) // Initialize AVPlayer with playerItem
        player?.play() // Start audio playback
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
            let cell = tableView.dequeueReusableCell(withIdentifier: TableView.CellIdentifiers.loadingCell, for: indexPath) // Dequeue loading cell
            let spinner = cell.viewWithTag(100) as! UIActivityIndicatorView // Get spinner from cell
            spinner.startAnimating() // Start the spinner animation
            return cell // Return loading cell
        } else if searchResults.isEmpty && hasSearched {
            let cell = tableView.dequeueReusableCell(withIdentifier: TableView.CellIdentifiers.ResultCell, for: indexPath) as! ResultCell // Dequeue result cell
            cell.nameLabel.text = "(Nothing found)" // Set "Nothing found" text
            cell.artistNameLabel.text = "" // Clear artist name label
            cell.artworkImageView.image = nil // Clear artwork image
            cell.hideActivityIndicator() // Hide activity indicator
            return cell // Return result cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: TableView.CellIdentifiers.ResultCell, for: indexPath) as! ResultCell // Dequeue result cell
            let searchResult = searchResults[indexPath.row] // Get search result for the current row
            cell.nameLabel.text = searchResult.trackName // Set track name label
            if searchResult.artist.isEmpty {
                cell.artistNameLabel.text = "Unknown" // Set artist name to "Unknown" if empty
            } else {
                cell.artistNameLabel.text = String(format: "%@ (%@)", searchResult.artist, searchResult.type) // Set artist name and type
            }
            cell.artworkImageView.image = UIImage(systemName: "square") // Placeholder image
            if let url = URL(string: searchResult.imageSmall) {
                loadArtworkImage(url: url, for: cell) // Load artwork image
            }
            cell.hideActivityIndicator() // Hide activity indicator
            return cell // Return result cell
        }
    }
    
    func loadArtworkImage(url: URL, for cell: ResultCell) {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in // Create data task
            if let data = data, let image = UIImage(data: data) { // Check if data is valid and create image
                DispatchQueue.main.async {
                    cell.artworkImageView.image = image // Update the image view with the downloaded image
                }
            }
        }
        task.resume() // Start the data task
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let searchResult = searchResults[indexPath.row] // Get search result for the selected row
        if let previewUrlString = searchResult.previewUrl, let previewUrl = URL(string: previewUrlString) { // Get preview URL
            if let cell = tableView.cellForRow(at: indexPath) as? ResultCell {
                cell.showActivityIndicator() // Show and animate the activity indicator
            }
            playAudio(url: previewUrl) // Play the audio preview
        }
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if searchResults.isEmpty || isLoading {
            return nil // Prevent row selection if loading or no results
        } else {
            // Hide activity indicator in previously selected cell
            if let selectedIndexPath = tableView.indexPathForSelectedRow, let cell = tableView.cellForRow(at: selectedIndexPath) as? ResultCell {
                cell.hideActivityIndicator() // Hide activity indicator in previously selected cell
            }
            return indexPath // Allow row selection
        }
    }
}

// MARK: - UIBarPositioningDelegate
extension SuperTunes: UIBarPositioningDelegate {
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached // Position the bar at the top
    }
}

// MARK: - Search Bar Delegate
extension SuperTunes: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if !searchBar.text!.isEmpty {
            searchBar.resignFirstResponder() // Dismiss the keyboard
            isLoading = true // Set loading flag to true
            tableView.reloadData() // Reload table view to show loading spinner
            hasSearched = true // Set hasSearched flag to true
            searchResults = [] // Clear previous search results
            
            let queue = DispatchQueue.global() // Create a background queue
            let url = self.iTunesURL(searchText: searchBar.text!) // Create URL for search
            queue.async { // Perform network request on background thread
                if let data = self.performStoreRequest(with: url) { // Perform store request
                    self.searchResults = self.parse(data: data) // Parse search results
                    self.searchResults.sort(by: <) // Sort search results
                    DispatchQueue.main.async {
                        self.isLoading = false // Set loading flag to false
                        self.tableView.reloadData() // Reload table view with search results
                    }
                    return
                }
            }
        }
    }
}

// Comparison function to sort search results by name
func < (lhs: SearchResult, rhs: SearchResult) -> Bool {
    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending // Compare names to sort in ascending order
}
