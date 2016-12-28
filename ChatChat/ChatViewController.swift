/*
 * Copyright (c) 2015 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import Firebase
import JSQMessagesViewController

final class ChatViewController: JSQMessagesViewController {
    
    // MARK: Properties
    let defaults = UserDefaults.standard
    
    var userRef: FIRDatabaseReference?
    private var messageRef: FIRDatabaseReference?
    private var newMessageRefHandle: FIRDatabaseHandle?
    
    var todayEvents = [Event]()
    var currentEvent: Event?
    var seenEventFilter: Double?
    private var eventRef: FIRDatabaseReference?
    private var eventRefHandle: FIRDatabaseHandle?
    
    var messages = [JSQMessage]()
    
    lazy var outgoingBubbleImageView: JSQMessagesBubbleImage = self.setupOutgoingBubble()
    lazy var incomingBubbleImageView: JSQMessagesBubbleImage = self.setupIncomingBubble()
    
    // interactions
    var moreButton: UIButton!
    var nextButton: UIButton!
    
    enum eventDetailStatus {
        case getEventDetail
        case getNextEvent
    }
    
    var currentEventDetailStatus = eventDetailStatus.getEventDetail
    
    // MARK: View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // one-liner to simulate new user
//        defaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        
        // MARK: - Data prep
        self.senderId = FIRAuth.auth()?.currentUser?.uid
        print("here is the userRef \(self.senderId) and senderDisplayName \(senderDisplayName)")
        
        observeMessages()
        
        //update filters
        if let todayDate = defaults.string(forKey: "eventDateFilter") {
            
            // if same date, get latest eventSeenFilter
            if todayDate == getTodayDateString() {
                seenEventFilter = defaults.double(forKey: "eventSeenFilter")
                print("same date! set seen filter, leave date alone.")
                
            // if different date, reset both filters
            } else {
                defaults.set(getTodayDateString(), forKey: "eventDateFilter")
                defaults.set(10000, forKey: "eventSeenFilter")
                seenEventFilter = defaults.double(forKey: "eventSeenFilter")
                print("new date! reset both filters.")

            }
        } else {
            
            // set initial date filter
            defaults.set(getTodayDateString(), forKey: "eventDateFilter")
            defaults.set(10000, forKey: "eventSeenFilter")
            seenEventFilter = defaults.double(forKey: "eventSeenFilter")
            print("new user! placeholders for both filters.")

        }
        
        // MARK: - Programmatic views
        
        //Create buttons
        let moreBut = UIButton()
        moreBut.sizeToFit()
        moreBut.contentEdgeInsets = UIEdgeInsetsMake(5,5,5,5)
        moreBut.backgroundColor = UIColor(red:1.00, green:0.64, blue:0.00, alpha:1.0)
        moreBut.setTitle("more", for: .normal)
        moreBut.setTitleColor(UIColor.white, for: .normal)
        moreBut.layer.cornerRadius = 10
        moreBut.addTarget(self, action: #selector(moreAction), for: UIControlEvents.touchUpInside)
        
        let nextBut = UIButton()
        nextBut.sizeToFit()
        nextBut.contentEdgeInsets = UIEdgeInsetsMake(5,5,5,5)
        nextBut.backgroundColor = UIColor(red:1.00, green:0.64, blue:0.00, alpha:1.0)
        nextBut.setTitle("next", for: .normal)
        nextBut.setTitleColor(UIColor.white, for: .normal)
        nextBut.layer.cornerRadius = 10
        nextBut.addTarget(self, action: #selector(nextAction), for: UIControlEvents.touchUpInside)
        
        //Stack View
        let stackView   = UIStackView()
        stackView.axis  = UILayoutConstraintAxis.horizontal
        stackView.distribution  = UIStackViewDistribution.equalSpacing
        stackView.alignment = UIStackViewAlignment.center
        stackView.spacing   = 24.0
        
        stackView.addArrangedSubview(moreBut)
        stackView.addArrangedSubview(nextBut)
        stackView.translatesAutoresizingMaskIntoConstraints = false;
        
        self.view.addSubview(stackView)
        moreButton = moreBut
        nextButton = nextBut
        
        //Constraints
        stackView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        stackView.centerYAnchor.constraint(equalTo: view.bottomAnchor, constant: -25).isActive = true
        // better to make it equadistant from bottomanchor and bottom of tableview than constant
        
        // MARK: - UI prep
        
        self.title = "histobotto"
        self.inputToolbar.isHidden = true
        //        self.collectionView.collectionViewLayout.springinessEnabled = true
        
        // No avatars
        collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
        collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    deinit {
        if let refHandle = eventRefHandle {
            eventRef?.removeObserver(withHandle: refHandle)
        }
    }
    
    // MARK :Actions
    
    func moreAction(sender:UIButton!) {
        guard sender == moreButton else { return }
        print("More Button Clicked")
        saveTextAsMessageInFirebase(sender.currentTitle!, senderId: senderId, senderName: senderDisplayName)
        currentEventDetailStatus = .getEventDetail
        checkEventDetailStatus()
    }
    
    func nextAction(sender:UIButton!) {
        guard sender == nextButton else { return }
        print("Next Button Clicked")
        saveTextAsMessageInFirebase(sender.currentTitle!, senderId: senderId, senderName: senderDisplayName)
        currentEventDetailStatus = .getNextEvent
        checkEventDetailStatus()
    }
    
    // MARK: Collection view data source (and related) methods
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!,
                                 messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.item]
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!,
                                 messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages[indexPath.item] // 1
        if message.senderId == senderId { // 2
            return outgoingBubbleImageView
        } else { // 3
            return incomingBubbleImageView
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
        let message = messages[indexPath.item]
        
        if message.senderId == senderId {
            cell.textView?.textColor = UIColor.white
        } else {
            cell.textView?.textColor = UIColor.black
        }
        return cell
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!,
                                 avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        return nil
    }
    
    // MARK: Firebase related methods
    
    private func observeMessages() {
        print("   getting saved messages via observeMessages")
        messageRef = userRef!.child("messages")
        let messageQuery = messageRef?.queryLimited(toLast:20)
        
        // 2. We can use the observe method to listen for new
        // messages being written to the Firebase DB
        newMessageRefHandle = messageQuery?.observe(.childAdded, with: { (snapshot) -> Void in
            let messageData = snapshot.value as! Dictionary<String, String>
            
            if let id = messageData["senderId"] as String!,
                let name = messageData["senderName"] as String!,
                let text = messageData["text"] as String!,
                text.characters.count > 0 {
                
                // 4
                self.addMessage(withId: id, name: name, text: text)
                print("Message Sent & Saved! \(name) said '\(text)'.")
                
                // 5
                self.finishReceivingMessage()
                
            } else {
                print("Error! Could not decode message data")
            }
        })
        self.observeEvents()
    }
    
    private func observeEvents() {
        print("   getting today's events via observeEvents")
        let todayDateString = getTodayDateString()
        self.eventRef = FIRDatabase.database().reference().child("events").child(todayDateString)
        
        var tempEvents: [Event] = []
        
        eventRef?.queryOrdered(byChild: "event_pop_rank").observeSingleEvent(of: .value, with: { (snapshot) in
            for item in snapshot.children {
                let child = item as! FIRDataSnapshot
                let eventFullValues = child.value as! NSDictionary
                
                let id = eventFullValues["event_id"] as! Int
                let event_title = eventFullValues["event_title"] as! String
                let year = eventFullValues["event_year"] as! String
                let event_pop_rank = eventFullValues["event_pop_rank"] as! Double
                let title = eventFullValues["title"] as! String
                
                if year > "1900" { //use queryOrder/Limit to limit local data (popularity?), then use other metrics for filtering
                    print("event_pop_rank: \(event_pop_rank) for \(event_title)")
                    tempEvents.append(Event(event_id: id, event_title: event_title, event_year: year, event_pop_rank: event_pop_rank, title: title))
                } else {
                    //                    print("too old")
                }
            }
            
            let numberOfEventsForToday = tempEvents.count
            
            // reverse array and take top 10
            tempEvents.reverse()
            tempEvents = Array(tempEvents.prefix(10))
            
            // reset event_pop_rank to latest
            tempEvents = tempEvents.filter { Double($0.event_pop_rank) < self.seenEventFilter! }
            self.todayEvents = tempEvents
            print("\(self.todayEvents.count) events left to share out of \(numberOfEventsForToday)")
            
            // open conversation using top event
            self.startEventTopic()
        })
    }
    
    private func startEventTopic(){
        // filter prior events, gets and sets current event
        if todayEvents.isEmpty == false {
            currentEvent = todayEvents[0]
            todayEvents.remove(at: 0)
            
            // formats opening message using currentYear and eventYear
            if let currentEvent = currentEvent {
                print("set current event to: \(currentEvent.event_title)")
                let calendar = NSCalendar.current
                let currentYear = calendar.component(.year, from: Date())
                
                let title = currentEvent.title
                let eventYear = Int(currentEvent.event_year)
                let text = "\(currentYear-eventYear!) years ago today, \(title)"
                
                saveTextAsMessageInFirebase(text, senderId: "Histobotto", senderName: "Histobotto")
                
                let latestEventFilter = Double(currentEvent.event_pop_rank)
                seenEventFilter = latestEventFilter
                defaults.set(latestEventFilter, forKey: "eventSeenFilter")
                print("current event filter is \(seenEventFilter)")
            }
            
            print("the next event is \(todayEvents[0].event_title)")
        }
    }
    
    // MARK: User Interaction
    
    private func getEventDetail() {
        print("user wants more, need follow up reply besides year: \(currentEvent?.event_year)")
        
        // pending description / link data
        if currentEvent != nil {
            let descriptionYetToCome = "need more description blob"
            let linkYetToCome = "need link url"
            
            saveTextAsMessageInFirebase(descriptionYetToCome+linkYetToCome, senderId: "Histobotto", senderName: "Histobotto")
            print("saved description message to firebase!")
        }
    }
    
    override func didPressSend(_ button: UIButton!,
                               withMessageText text: String!,
                               senderId: String!,
                               senderDisplayName: String!,
                               date: Date!) {
        guard let text = text else {
            assertionFailure("The conversation number or text is nil")
            return
        }
        
        saveTextAsMessageInFirebase(text, senderId: senderId, senderName: senderDisplayName)
        JSQSystemSoundPlayer.jsq_playMessageSentSound() // 4
        
        finishSendingMessage() // 5 - send and reset input toolbar to empty
        print("user had a response: \(text)")
        
        // change eventDetailStatus and then exercise switch statement to get HB response
        if (text.caseInsensitiveCompare("yes") == ComparisonResult.orderedSame) {
            currentEventDetailStatus = .getEventDetail
            print("user wants more, switch enum to getEventDetail, run getEventDetail(), update responses")
        } else if (text.caseInsensitiveCompare("next") == ComparisonResult.orderedSame) {
            currentEventDetailStatus = .getNextEvent
            print("user wants next, switch enum to getNextEvent, run startNextTopic(), update responses")
        }
        
        checkEventDetailStatus()
    }
    
    // MARK: UI
    
    private func setupOutgoingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.outgoingMessagesBubbleImage(with: UIColor(red:1.00, green:0.64, blue:0.00, alpha:1.0))
    }
    
    private func setupIncomingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleLightGray())
    }
    
    // MARK: Helper functions
    
    //get today's date
    func getTodayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        let stringDate = formatter.string(from: Date())
        return stringDate
    }
    
    private func addMessage(withId id: String, name: String, text: String) {
        if let message = JSQMessage(senderId: id, displayName: name, text: text) {
            messages.append(message)
        }
    }
    
    private func checkEventDetailStatus() {
        switch currentEventDetailStatus {
        case .getEventDetail:
            getEventDetail()
        case .getNextEvent:
            startEventTopic()
        }
    }
    
    private func saveTextAsMessageInFirebase(_ text: String, senderId: String, senderName: String) {
        let itemRef = messageRef?.childByAutoId() // 1 - create child ref with unique key
        let messageItem = [ // 2 - create dict to represent message
            "senderId": senderId,
            "senderName": senderName,
            "text": text,
            "messageTime": Date().datetime
        ]
        
        itemRef?.setValue(messageItem) // 3 - save value at child location
    }
    
    // MARK: UITextViewDelegate methods
}
