//
//  PostViewController.swift
//  ListenUp
//
//  Created by Harshad Barapatre on 4/18/22.
//

import UIKit
import AVFAudio
import Parse
import UIKit
import ProgressHUD

class NewPostViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    
    var searchResults: [SongResult] = []
    var searchQuery = String()
    var whatsPlaying: ResultTableViewCell? = nil
    
    var searchAttempt = 0
    
    var returningViewController: FeedViewController? = nil
    var returningPagedViewController: PageViewTemplateController? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "Post"
        
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        
        tableView.allowsSelection = false
        
        searchBar.searchTextField.placeholder = "Search Songs"
        searchBar.becomeFirstResponder()
        
//        tableView.separatorColor = UIColor.clear
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ResultTableViewCell") as? ResultTableViewCell else {
            return UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        }
        
        var result: SongResult?
        if indexPath.row >= searchResults.count {
            cell.postSymbol.isUserInteractionEnabled = false
            result = nil
        }
        else {
            result = searchResults[indexPath.row]
            cell.result = result!
            cell.postSymbol.isUserInteractionEnabled = true
        }
        
        guard let fineResult = result else {
            return cell
        }
        
        let clean = UserDefaults.standard.bool(forKey: "prefersCleanContent")
        
        cell.albumArtworkView.image = UIImage(named: "default.jpg")!
        cell.trackNameLabel?.text = clean ? fineResult.trackCensoredName : fineResult.trackName
        cell.artistNameLabel?.text = fineResult.artistName

        guard let albumArtworkURL = URL(string: fineResult.artworkUrl100) else {
            return cell
        }

        cell.albumArtworkView?.load(url: albumArtworkURL, completion: nil)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(userTriedToPostSong(_:)))
        tapGesture.numberOfTapsRequired = 1
        cell.postSymbol.addGestureRecognizer(tapGesture)
        
        // Source: https://stackoverflow.com/a/35019685
        cell.darkeningLayer.frame = cell.albumArtworkView.bounds;
        cell.darkeningLayer.backgroundColor = UIColor.black.cgColor
        cell.darkeningLayer.opacity = nonPlayingArtworkOpacity
        cell.albumArtworkView.layer.addSublayer(cell.darkeningLayer)
        
        //
        // MARK: Media Button Work
        //
        
        // To identify which cell's button got called, we can use tag to pass the indexPath row
        cell.mediaButton.tag = indexPath.row
        
        cell.mediaButton.layer.shadowRadius = 10
        cell.mediaButton.layer.shadowOpacity = 0.8
        
        // To prevent having two Storyboard connections, I'm using the outlet to make an action
        cell.mediaButton.addTarget(self, action: #selector(userPressedMediaButton), for: .touchUpInside)
        
        cell.separatorInset = UIEdgeInsets(top: 0, left: 100, bottom: 0, right: 0)
        
        return cell
    }
    
    @objc func userPressedMediaButton(_ sender: UIButton) {
        let post = searchResults[sender.tag]
        guard let cell = tableView.cellForRow(at: IndexPath(row: sender.tag, section: 0)) as? ResultTableViewCell else {
            print("Could not find post cell with given indexPath")
            return
        }
        
        if let oldPlay = whatsPlaying {
            // The user was already playing something, we need to turn that off first
            whatsPlaying?.enterPausedState()
            whatsPlaying = nil
            
            // Also, check that the one we're turning off isn't the user trying to turn it off themselves
            // Otherwise, we must return early
            if oldPlay == cell {
                return
            }
        }
        
        // Now that nothing is playing, let's play the next song
        // (we've already handled the case where the user stops a song above)
        cell.isPlaying = true
        whatsPlaying = cell
        cell.mediaButton.setImage(UIImage(systemName: "pause.circle.fill"), for: .normal)
        cell.darkeningLayer.opacity = playingArtworkOpacity
        cell.player.initPlayer(url: post.previewUrl) {
            cell.enterPausedState()
        }
        cell.player.play()
    }
    
    func getSearchResults(_ searchQuery: String, currAttempt: Int) {
        retrieveITUNESResults(rawSearchTerm: searchQuery) { results in
            if currAttempt == self.searchAttempt {
                print("query working: \(searchQuery)")
                // Can't run UI code on background thread
                DispatchQueue.main.async {
                    self.searchResults = results
                    self.tableView.reloadData()
                }
            }
            else {
                print("avoiding possibly useless table reload: \(searchQuery)")
            }
            
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
//        if searchText == "" {
//            searchAttempt = 0
//        }
        searchAttempt += 1
        let saveSearchAttempt = searchAttempt
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if searchText != "" && self.searchAttempt == saveSearchAttempt {
                self.getSearchResults(searchText.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "", currAttempt: saveSearchAttempt)
                print("Allowed search attempt \(saveSearchAttempt)")
            }
            else {
                print("Prevented search attempt \(saveSearchAttempt)")
            }
        }
        
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchBar.showsCancelButton = false
        searchAttempt += 1
        if searchBar.text != "" {
            self.getSearchResults(searchBar.text?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "", currAttempt: searchAttempt)
        }
        
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            self.searchBar.showsCancelButton = true
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            searchBar.showsCancelButton = false
            searchBar.text = ""
            searchBar.resignFirstResponder()
    }
    
    @objc func userTriedToPostSong(_ sender: UITapGestureRecognizer) {
        if sender.state == UIGestureRecognizer.State.ended {
            let tapLocation = sender.location(in: self.tableView)
            if let tapIndexPath = self.tableView.indexPathForRow(at: tapLocation) {
                if let tappedCell = self.tableView.cellForRow(at: tapIndexPath) as? ResultTableViewCell {
                    guard let result = tappedCell.result else {
                        ProgressHUD.showFailed()
                        print("post not set for tappedCell")
                        return
                    }
                    
                    ProgressHUD.animationType = .lineScaling
                    ProgressHUD.colorAnimation = jellyColor
                    ProgressHUD.show("Posting...")
                    
                    var flag = false
                    
                    if let parent = self.returningViewController {
                        flag = parent.posts.contains { post in
                            post.trackViewUrl == result.trackViewUrl
                        }
                    }
                    else if let parent = self.returningPagedViewController {
                        flag = parent.posts.contains { post in
                            post.trackViewUrl == result.trackViewUrl
                        }
                    }
                    
                    if flag {
                        ProgressHUD.showError("Someone already posted that")
                        return
                    }
                    
                    // Do Post processing here (pun intended)
                    let _ = Post(song: result, createdBy: User.current()!) { postReady in
                        postReady.saveInBackground { success, error in
                            guard success else {
                                print("An error occurred when posting the user's chosen song...")
                                if let error = error {
                                    print(error.localizedDescription)
                                }
                                else {
                                    print("No further details could be found.")
                                }
                                return
                            }
                        }
                        
                        DispatchQueue.main.async {
                            if let parent = self.returningViewController {
                                parent.posts.insert(postReady,at: 0)
                                parent.tableView.reloadData()
                            }
                            else if let parent = self.returningPagedViewController {
                                parent.posts.insert(postReady, at: 0)
                                parent.reloadChildViewControllers()
                            }
                            self.dismiss(animated: true)
                        }
                    }
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        whatsPlaying?.enterPausedState()
        ProgressHUD.dismiss()
    }
}
