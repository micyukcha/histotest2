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
    
    var userRef: FIRDatabaseReference?
    private var messageRef: FIRDatabaseReference?
    private var newMessageRefHandle: FIRDatabaseHandle?
    
    var events = [Event]()
    var currentEvent: Event?
    private var eventRef: FIRDatabaseReference?
    private var eventRefHandle: FIRDatabaseHandle?
    
    var messages = [JSQMessage]()
    
    lazy var outgoingBubbleImageView: JSQMessagesBubbleImage = self.setupOutgoingBubble()
    lazy var incomingBubbleImageView: JSQMessagesBubbleImage = self.setupIncomingBubble()
    
    enum eventDetailStatus {
        case getEventDetail
        case getNextEvent
    }
    
    var currentEventDetailStatus = eventDetailStatus.getEventDetail
    
    
    // MARK: View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.senderId = FIRAuth.auth()?.currentUser?.uid
        print("here is the userRef \(self.senderId) and senderDisplayName \(senderDisplayName)")
        
        // MARK: - Data prep
        
        observeMessages()
        print(self.userRef)
        
        // MARK: - Programmatic views
        
        //Create buttons
        let detailsButton = UIButton()
        detailsButton.sizeToFit()
        detailsButton.contentEdgeInsets = UIEdgeInsetsMake(5,5,5,5)
        detailsButton.backgroundColor = UIColor(red:1.00, green:0.64, blue:0.00, alpha:1.0)
        detailsButton.setTitle("more", for: .normal)
        detailsButton.setTitleColor(UIColor.white, for: .normal)
        detailsButton.layer.cornerRadius = 10
        
        let nextButton = UIButton()
        nextButton.sizeToFit()
        nextButton.contentEdgeInsets = UIEdgeInsetsMake(5,5,5,5)
        nextButton.backgroundColor = UIColor(red:1.00, green:0.64, blue:0.00, alpha:1.0)
        nextButton.setTitle("next", for: .normal)
        nextButton.setTitleColor(UIColor.white, for: .normal)
        nextButton.layer.cornerRadius = 10
        
        //Stack View
        let stackView   = UIStackView()
        stackView.axis  = UILayoutConstraintAxis.horizontal
        stackView.distribution  = UIStackViewDistribution.equalSpacing
        stackView.alignment = UIStackViewAlignment.center
        stackView.spacing   = 16.0
        
        stackView.addArrangedSubview(detailsButton)
        stackView.addArrangedSubview(nextButton)
        stackView.translatesAutoresizingMaskIntoConstraints = false;
        
        self.view.addSubview(stackView)
        
        //Constraints
        stackView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        stackView.centerYAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        
        // MARK: - UI prep
        
        self.title = "histobotto"
        // self.collectionView.collectionViewLayout.springinessEnabled = true
         self.inputToolbar.isHidden = true
        
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
            print("saved message: \(messageData)")
            
            if let id = messageData["senderId"] as String!,
                let name = messageData["senderName"] as String!,
                let text = messageData["text"] as String!,
                text.characters.count > 0 {
                
                // 4
                self.addMessage(withId: id, name: name, text: text)
                
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
        
        eventRef?.queryOrdered(byChild: "title").queryLimited(toFirst: 30).observeSingleEvent(of: .value, with: { (snapshot) in
            for item in snapshot.children {
                let child = item as! FIRDataSnapshot
                let eventFullValues = child.value as! NSDictionary
                
                let id = eventFullValues["event_id"] as! Int
                let event_title = eventFullValues["event_title"] as! String
                let year = eventFullValues["event_year"] as! String
                let title = eventFullValues["title"] as! String
                
                if year > "1900" { //use queryOrder/Limit to limit local data (popularity?), then use other metrics for filtering
                    print("event_title: \(event_title)")
                    tempEvents.append(Event(event_id: id, event_title: event_title, event_year: year, title: title))
                } else {
                    //                    print("too old")
                }
            }
            self.events = tempEvents
            print("events to share for today? \(self.events.isEmpty == false)")
            
            // open conversation using top event
            self.startEventTopic()
        })
    }
    
    private func startEventTopic(){
        // gets and sets current event
        if events.isEmpty == false {
            currentEvent = events[0]
            events.remove(at: 0)
            
            // formats opening message using event and current year
            if let currentEvent = currentEvent {
                print("set current event to: \(currentEvent.event_title)")
                let title = currentEvent.title
                let eventYear = Int(currentEvent.event_year)
                
                let calendar = NSCalendar.current
                let currentYear = calendar.component(.year, from: Date())
                
                let text = "\(currentYear-eventYear!) years ago, \(title)"
                
                // 1 - create child ref with unique key for intro message
                messageRef = userRef?.child("messages")
                let itemRef = messageRef?.childByAutoId()
                
                let messageItem = [ // 2 - create dict to represent message
                    "senderId": "Histobotto",
                    "senderName": "Histobotto",
                    "text": text,
                    "messageTime": Date().datetime
                ]
                print("converted event to message!")
                
                itemRef?.setValue(messageItem) // 3 - save value at child location
                print("saved message to firebase at userRef \(userRef)!")
            }
            print("the next event is \(events[0].event_title)")
        }
    }
    
    // MARK: User Interaction
    
    private func getEventDetail() {
        print("user wants more, need follow up reply besides year: \(currentEvent?.event_year)")
        
        // pending description / link data
        if let currentEvent = currentEvent {
            let descriptionYetToCome = currentEvent.title
            let linkYetToCome = currentEvent.title
            
            // 1 - create child ref with unique key for intro message
            messageRef = userRef?.child("messages")
            let itemRef = messageRef?.childByAutoId()
            
            let messageItem = [ // 2 - create dict to represent message
                "senderId": "Histobotto",
                "senderName": "Histobotto",
                "text": descriptionYetToCome,
                "messageTime": Date().datetime
            ]
            print("converted description to message!")
            
            itemRef?.setValue(messageItem) // 3 - save value at child location
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
        
        let itemRef = messageRef?.childByAutoId() // 1 - create child ref with unique key
        let messageItem = [ // 2 - create dict to represent message
            "senderId": senderId!,
            "senderName": senderDisplayName!,
            "text": text,
            "messageTime": Date().datetime
        ]
        
        itemRef?.setValue(messageItem) // 3 - save value at child location
        
        JSQSystemSoundPlayer.jsq_playMessageSentSound() // 4
        
        finishSendingMessage() // 5 - send and reset input toolbar to empty
        print("user had a message: \(messageItem)")
        
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
    
    // MARK: UITextViewDelegate methods
}
