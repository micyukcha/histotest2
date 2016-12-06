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
    private var eventRef: FIRDatabaseReference?
    private var eventRefHandle: FIRDatabaseHandle?
    
    var messages = [JSQMessage]()
    
    lazy var outgoingBubbleImageView: JSQMessagesBubbleImage = self.setupOutgoingBubble()
    lazy var incomingBubbleImageView: JSQMessagesBubbleImage = self.setupIncomingBubble()
    
    // MARK: View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.senderId = FIRAuth.auth()?.currentUser?.uid
        
        // No avatars
        collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
        collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
        
        observeEvents()
        
        print(self.userRef)
        print(senderDisplayName)
        
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
    
    private func observeEvents() {
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
            print("this is the tempEvents: \(tempEvents)")
            self.events = tempEvents
            print("this is the post-events: \(self.events)")
            
            // put event into conversation
            self.saveTopEventToConversation()
        })
    }
    
    private func saveTopEventToConversation(){
        // use first event
        print("this is the first event: \(events[0].event_title)")
        print("this is the userRef for messages: \(userRef)")
        let event = events[0]
        events.remove(at: 0)
        
        // 1 - create child ref with unique key, no userRef at time?
        messageRef = userRef?.child("messages")
        let itemRef = messageRef?.childByAutoId()
        
        let messageItem = [ // 2 - create dict to represent message
            "senderId": senderId!,
            "senderName": "Histbotto",
            "title": event.title,
            "eventYear": event.event_year,
            "messageTime": Date().datetime
        ]
        
        itemRef?.setValue(messageItem) // 3 - save value at child location
        
        //        JSQSystemSoundPlayer.jsq_playMessageReceivedSound()
        //        finishReceivingMessage()
        
        print("this is the messageItem: \(messageItem)")
        print("this is the itemRef: \(itemRef)")
        print("saved event to firebase!")
    }
    
    //    // read firebase event in as message
    //    let text = event.title
    //    addMessage(withId: "foo", name: "Histbotto", text: text)
    //    print("these are the messages: \(messages)")
    //    //        observeMessages()
    
    
    //    private func observeMessages() {
    //        messageRef = userRef!.child("messages")
    //        // 1.
    //        let messageQuery = messageRef?.queryLimited(toLast:25)
    //
    //        // 2. We can use the observe method to listen for new
    //        // messages being written to the Firebase DB
    //        newMessageRefHandle = messageQuery?.observe(.childAdded, with: { (snapshot) -> Void in
    //            // 3
    //            let messageData = snapshot.value as! Dictionary<String, String>
    //
    //            if let id = messageData["senderId"] as String!, let name = messageData["senderName"] as String!, let text = messageData["text"] as String!, text.characters.count > 0 {
    //                // 4
    //                self.addMessage(withId: id, name: name, text: text)
    //
    //                // 5
    //                self.finishReceivingMessage()
    //            } else {
    //                print("Error! Could not decode message data")
    //            }
    //        })
    //    }
    
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
            ]
        
        itemRef?.setValue(messageItem) // 3 - save value at child location
        
        JSQSystemSoundPlayer.jsq_playMessageSentSound() // 4
        
        finishSendingMessage() // 5 - send and reset input toolbar to empty
        print("works!")
        print("heyoMessage\(events)")
    }
    
    // MARK: UI and User Interaction
    
    private func setupOutgoingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleBlue())
    }
    
    private func setupIncomingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleLightGray())
    }
    
    private func addMessage(withId id: String, name: String, text: String) {
        if let message = JSQMessage(senderId: id, displayName: name, text: text) {
            messages.append(message)
        }
    }
    
    // MARK: UITextViewDelegate methods
    //get today's date
    func getTodayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        let stringDate = formatter.string(from: Date())
        return stringDate
    }
    
}
