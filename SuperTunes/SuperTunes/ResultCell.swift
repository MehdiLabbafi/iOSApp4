//
//  ResultCell.swift
//  SuperTunes
//
//  Created by Mehdi Labbafi on 2024-07-03.
//


import UIKit

class ResultCell: UITableViewCell {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var artistNameLabel: UILabel!
    @IBOutlet weak var artworkImageView: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView! // Add this outlet

    override func awakeFromNib() {
        super.awakeFromNib()
        activityIndicator.isHidden = true // Hide the activity indicator by default
    }

    func showActivityIndicator() {
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
    }

    func hideActivityIndicator() {
        activityIndicator.isHidden = true
        activityIndicator.stopAnimating()
    }
}
