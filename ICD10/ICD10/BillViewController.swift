/*
*  BillViewController.swift
*   A class to represent a bill/visit in a medical practice
*
*  Created by Brandon S Roberts on 6/4/15.
*  Copyright (c) 2015 Brandon S Roberts. All rights reserved.
*/

import UIKit

class BillViewController: UIViewController, UITextFieldDelegate, UIPopoverPresentationControllerDelegate, DidBeginBillWithPatientInformationDelegate, LXReorderableCollectionViewDataSource, LXReorderableCollectionViewDelegateFlowLayout{
    
    
    //MARK: - Controllers, Views and Database manager
    var dbManager:DatabaseManager!
    var searchTableViewController: SearchTableViewController?               //A view controller for the popup table view
    var modifierTablieViewcontroller: ModifierTableViewController?          //TVC for the modifier popup
    var billViewController:BillViewController?
    @IBOutlet weak var codeCollectionView: UICollectionView!
    @IBOutlet weak var scrollView: UIScrollView!//A bill that is passed along to hold all of the codes for the final bill
    
    //MARK: - Action Buttons/Switches
    @IBOutlet weak var codeVersion: UISwitch!                               //Determines what version of codes to use in the bill (ICD10 default)
    @IBOutlet weak var icdType: UILabel!
    @IBOutlet weak var billCompletionLabel: UILabel!
    @IBOutlet weak var billCompletionSwitch: UISwitch!
    @IBOutlet weak var saveBillButton: UIButton!
    @IBOutlet weak var adminDocButton: UIButton!
    
    
    //MARK: - TextFields
    @IBOutlet weak var patientTextField: UITextField!
    @IBOutlet weak var patientDOBTextField: UITextField!
    @IBOutlet weak var doctorTextField: UITextField!
    @IBOutlet weak var siteTextField: UITextField!
    @IBOutlet weak var roomTextField: UITextField!
    @IBOutlet weak var cptTextField: UITextField!
    @IBOutlet weak var mcTextField: UITextField!
    @IBOutlet weak var pcTextField: UITextField!
    @IBOutlet weak var dateTextField: UITextField!
    
    //MAKR: - Bill Data
    var administeringDoctor:String?
    var icd10On:Bool!
    var textFieldText:[String] = []                                         //A list of saved items for the bill
    var codesForBill:[String:[(icd10:String, icd9:String, icd10id:Int, extensionCode:String)]] = [:]
    var visitCodePriority:[String] = []
    var modifierCodes:[String:Int] = [:]                                    //visitCode -> modifierCode
    
    //MARK: - Optional Data
    
    var appointmentID:Int?                                                  //The appointment id if this is a saved bill
    var billComplete:Bool?
    var newPatient:String?
    var newPatientDOB:String?
    var selectedVisitCodeToAddTo:String?
    var shouldRemoveBackButton:Bool?
    
    // MARK: - View Management
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        dbManager = DatabaseManager()
        dbManager.checkDatabaseVersionAndUpdate()
        
        self.navigationItem.title = "Bill"
        self.fillFormTextFields()
        
        if let billPatient = newPatient {                                   //Possible received newPatient from AdminDocVC
            patientTextField.text = billPatient
            
            if let patientDOB = newPatientDOB {
                patientDOBTextField.text = patientDOB
            }
        }

        codeCollectionView.delegate = self                                  //Set the BillVC as the controller for the collectionView
        codeCollectionView.dataSource = self
        codeCollectionView.collectionViewLayout = LXReorderableCollectionViewFlowLayout()
        
        let layout = codeCollectionView.collectionViewLayout                //Configure collectionView
        let flow  = layout as! LXReorderableCollectionViewFlowLayout
        flow.headerReferenceSize = CGSizeMake(100, 35)
        
        let screenSize: CGRect = UIScreen.mainScreen().bounds
        let screenWidth = screenSize.width
        var screenHeight = screenSize.height
        
        screenHeight = screenHeight * 2
        self.scrollView.contentSize = CGSizeMake(screenWidth, screenHeight)
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        billCompletionSwitch.on = false                                     //initially set the bill to incomplete
        
        let defaults = NSUserDefaults.standardUserDefaults()
        if !defaults.boolForKey("notFirstBill") {
            defaults.setBool(true, forKey: "notFirstBill")
            showAlert("This is the bill page!", msg: "Fill in bill information and insert a visit code by searching for a CPT, Procedure, or Medicare code!")
        }
        
        //var codesForBill:[String:[(icd10:String, icd9:String, icd10id:Int, extensionCode:String)]] = [:]
        let values = (codesForBill.values)
        if values.count > 0 && !defaults.boolForKey("notFirstICD10Code") {
            defaults.setBool(true, forKey: "notFirstICD10Code")
            showAlert("ICD-10 Codes", msg: "You added your first ICD-10 code! If you add more than one to a particular visit code, you can tap and drag them to rearrange their priority!")
        }
        
        setTabBarVisible(true, animated: true)
    }
    
    override func viewWillAppear(animated: Bool) {
        
        if let icd10CodesChosen = icd10On {                                 //if icd10 is set make sure to display it correctly
            if icd10CodesChosen {
                codeVersion.setOn(true, animated: true)
            } else {
                codeVersion.setOn(false, animated: true)
                icdType.text = "ICD9"
            }
        }
        
        if let billIsComplete = billComplete {                              //Set the bill completion to display correctly
            if billIsComplete {
                billCompletionSwitch.on = true
                billCompletionLabel.text = "Bill Complete"
            } else {
                billCompletionSwitch.on = false
                billCompletionLabel.text = "Bill Incomplete"
            }
        }
        
        if let hasAdminDoc = administeringDoctor {
            self.adminDocButton.setTitle(administeringDoctor, forState: UIControlState.Normal)
        }
        
        if((shouldRemoveBackButton) != nil){
            self.navigationItem.hidesBackButton = true
        }
        self.addNotifications()
        self.codeCollectionView.reloadData()                                //Update the collectionView with any new data
        
        
    }
    
    override func viewWillDisappear(animated: Bool) {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func addNotifications() {                                          //listen for when a user selects an item from a popup
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updatePatient:",name:"loadPatient", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateDoctor:",name:"loadDoctor", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateCPT:",name:"loadTuple", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateSite:",name:"loadSite", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateRoom:",name:"loadRoom", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateModifier:",name:"loadModifier", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateAdminDoctor:",name:"loadAdminDoctor", object: nil)
    }
    
    func fillFormTextFields(){                                          //Load data into the text fields
        
        let date = NSDate()
        
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        formatter.dateFormat = "MM-dd-yyyy"
        
        if let aptID = appointmentID {                                  //If this is a saved bill get the date it was for
            dbManager.checkDatabaseFileAndOpen()
            dateTextField.text = dbManager.getDateForApt(aptID)
            dbManager.closeDB()
        }else {
            dateTextField.text = formatter.stringFromDate(date)
        }
        
        if self.textFieldText.count > 0 {
            patientTextField.text = textFieldText[0]
            patientDOBTextField.text = textFieldText[1]
            doctorTextField.text = textFieldText[2]
            siteTextField.text = textFieldText[3]
            roomTextField.text = textFieldText[4]
        }
    }
    
    @IBAction func switchCodeVersion(sender: UISwitch) {                //Switch the display of the icd10/icd9 code
        
        if codeVersion.on {
            icdType.text = "ICD10"
        }else {
            icdType.text = "ICD9"
        }
        codeCollectionView.reloadData()
    }
    
    @IBAction func switchBillCompletion(sender: UISwitch) {             //Switch the display of the bill completion label
        
        if sender.on {
            billCompletionLabel.text = "Bill Complete"
        } else {
            billCompletionLabel.text = "Bill Incomplete"
        }
    }
    
    
    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController) -> UIModalPresentationStyle { return UIModalPresentationStyle.None }
    
    override func didReceiveMemoryWarning() { super.didReceiveMemoryWarning() }
    
    // MARK: - DidBeginBillWithPatientInformationDelegate
    
    func userEnteredPatientInformationForBill(fName:String, lName:String, dateOfBirth:String){
        patientTextField.text = fName + " " + lName
        patientDOBTextField.text = dateOfBirth
    }
    
    
    // MARK: -  Clicks and Actions
    
    @IBAction func clickedInTextBox(sender: UITextField) {
        
        switch sender.tag {
        case 0:self.performSegueWithIdentifier("patientSearchPopover", sender: self)
        
        case 2:self.performSegueWithIdentifier("doctorSearchPopover", sender: self)
        case 3:self.performSegueWithIdentifier("siteSearchPopover", sender: self)
        case 4:self.performSegueWithIdentifier("roomSearchPopover", sender: self)
        case 5:self.performSegueWithIdentifier("cptSearch", sender: self)
        case 6:self.performSegueWithIdentifier("mcSearch", sender: self)
        case 7:self.performSegueWithIdentifier("pcSearch", sender: self)
        default:break
        }
    }
    
    @IBAction func clickedChangeAdmin(sender: UIButton) {
        self.performSegueWithIdentifier("adminDoctorSearchPopover", sender: self)
    }
    
    
    @IBAction func clickedVisitCodeDescriptionButton(sender: UIButton) {
        self.performSegueWithIdentifier("visitCodeDescriptionPopover", sender: sender)
    }
    
    
    /**
    *   Registers clicking return and resigns the keyboard
    **/
    @IBAction func textFieldDoneEditing(sender:UITextField){
        sender.resignFirstResponder()
    }
    
    @IBAction func backgroundTap(sender: UIControl){
        patientTextField.resignFirstResponder()
        patientDOBTextField.resignFirstResponder()
        doctorTextField.resignFirstResponder()
        siteTextField.resignFirstResponder()
        roomTextField.resignFirstResponder()
        cptTextField.resignFirstResponder()
        mcTextField.resignFirstResponder()
        pcTextField.resignFirstResponder()
    }
    
    // MARK: - Save Bill
    
    @IBAction func saveBill(sender: UIButton) {
        
        var defaults = NSUserDefaults.standardUserDefaults()
        if !defaults.boolForKey("notFirstBillSave") {
            defaults.setBool(true, forKey: "notFirstBillSave")
            showAlert("Is your bill complete?", msg: "When saving, you can mark the bill as complete with the completion switch. If incomplete, the bill will have a red flag next to it in the bills tab so you can update it later.")
        }else {
            
            var validityErr = self.checkValidityOfProvidedInputs()
            
            
            if validityErr != "" {
                self.showAlert("Error!",msg: validityErr)
                return
            }
            
            //test for the split of the name
            var (fName, lName) = dbManager.split(patientTextField.text!)
            if fName == "" {
                self.showAlert("Patient Error!", msg: "Please enter a patient first name and last name separated by a space.")
                return
            }
            
            if patientTextField.text == "" || patientDOBTextField.text == "" { //Make sure there is a patient to save for
                
                self.showAlert("Bill Save Error!", msg: "The bill must have a valid patient to be saved")
            } else{
                
                if billCompletionSwitch.on {                                    //Make sure it has all the information if the bill is complete
                    var error = self.checkInputs()
                    if error != ""{
                        self.showAlert("Bill Incomplete!", msg: "The bill was indicated as complete but an input is missing. \(error) ")
                        return
                    }
                }
                
                var placeID = getPlaceOfServiceID(siteTextField.text!)           //get the ids to input into the bill
                var roomID = getRoomID(roomTextField.text!)
                var patientID = getPatientID(patientTextField.text!, dateOfBirth: patientDOBTextField.text!)
                
                var referringDoctorID = getDoctorID(doctorTextField.text!)
                var adminDoctorID = getDoctorID(administeringDoctor!)
                
                if let aptID = appointmentID {                                  // if this bill is being updated
                    saveBillFromPreviousBill(aptID, placeID: placeID, roomID: roomID, patientID: patientID, referringDoctorID: referringDoctorID, adminDoctorID: adminDoctorID)
                }else {
                    saveNewBill(placeID, roomID: roomID, patientID: patientID, referringDoctorID: referringDoctorID, adminDoctorID: adminDoctorID)
                }
            }
        }
    }
    
    func saveBillFromPreviousBill(aptID:Int, placeID:Int, roomID:Int, patientID:Int, referringDoctorID:Int, adminDoctorID:Int){
        
        dbManager.checkDatabaseFileAndOpen()
        dbManager.removeModifiersForBill(aptID)
        dbManager.removeHasDoc(aptID)
        dbManager.updateAppointment(aptID, pID: patientID, placeID: placeID, roomID: roomID, code_type: Int(codeVersion.on), complete: Int(billCompletionSwitch.on), date:dateTextField.text!)
        
        self.addHasDoc(aptID, dID: referringDoctorID)                           //insert hasdoc for referring
        self.addHasDoc(aptID, dID: adminDoctorID)                               //insert hasdoc for admin
        dbManager.closeDB()
        
        dbManager.checkDatabaseFileAndOpen()
        let (initialCodes, visitPriority) = dbManager.getVisitCodesForBill(aptID)
        
        for var i=0; i<visitPriority.count; i++ {
            dbManager.checkDatabaseFileAndOpen()
            dbManager.removeCodesFromDatabase(aptID, aptCode: visitPriority[i]) //remove the old codes from the appointment so we can accurately add the currnt codes
            dbManager.closeDB()
        }
        
        saveCodesForBill(aptID, referringDoctorID: referringDoctorID, adminDoctorID: adminDoctorID)
        self.performSegueWithIdentifier("ViewAllBills", sender: self)
    }
    
    func saveNewBill(placeID:Int, roomID:Int, patientID:Int, referringDoctorID:Int, adminDoctorID:Int){
        var codeType = Int(codeVersion.on)
        var billComplete = Int(billCompletionSwitch.on)
        var (aptID, result) = addAppointmentToDatabase(patientID, date: dateTextField.text!, placeID: placeID, roomID: roomID, codeType: codeType, billComplete: billComplete)
        
        self.addHasDoc(aptID, dID: referringDoctorID)                           //insert hasdoc for referring
        self.addHasDoc(aptID, dID: adminDoctorID)                               //insert hasdoc for admin
        
        self.saveCodesForBill(aptID, referringDoctorID: referringDoctorID, adminDoctorID: adminDoctorID)
        
//        self.performSegueWithIdentifier("newBill", sender: self)                //start up a new bill after we have saved everything for this bill
        let storyBoard : UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        let controller = storyBoard.instantiateViewControllerWithIdentifier("BillViewController") as! BillViewController
        controller.administeringDoctor = self.administeringDoctor
        controller.shouldRemoveBackButton = true
        self.navigationController?.pushViewController(controller, animated: true)
    }
    
    func saveCodesForBill(aptID:Int, referringDoctorID:Int, adminDoctorID:Int){ //save all the codes from codesForBill Dictionary

        for var i=0; i<visitCodePriority.count; i++ {
            
            let visitCode = visitCodePriority[i]                                //retrieve visitCodes in the correct order
            var diagnosesForVisitCode:[(icd10:String, icd9:String, icd10id:Int, extensionCode:String)] = codesForBill[visitCode]!
            
            for var j=0; j<diagnosesForVisitCode.count; j++ {
                var (icd10, icd9, icd10id, extensionCode) = diagnosesForVisitCode[j]
                self.addHasType(aptID, visitCodeText: visitCode, icd10CodeID: icd10id, visitPriority: i, icdPriority: j, extensionCode: extensionCode)
            }
        }
        
        saveModifierCodesForBill(aptID)
    }
    
    func saveModifierCodesForBill(aptID: Int) {
        dbManager.checkDatabaseFileAndOpen()
        let modifierKeys = [String](modifierCodes.keys)
        //let modifierKeys = modifierCodes.keys.array
        for var i=0; i<modifierKeys.count; i++ {
            let visitCode = modifierKeys[i]
            dbManager.addHasModifiers(aptID, aptCode: visitCode, modifierID: modifierCodes[visitCode]!)
        }
        dbManager.closeDB()
    }
    
    func checkValidityOfProvidedInputs() -> String{
        var err = ""
        
        if patientTextField.text != "" {
            let fullNameArr = patientTextField.text!.componentsSeparatedByString(" ")
            if fullNameArr.count > 2 && fullNameArr[2] != ""{
                err = "An error occurred when saving the patient. Please enter a first name and last name separated by a space."
            }
        }
        
        if doctorTextField.text != "" {
            let fullNameArr = doctorTextField.text!.componentsSeparatedByString(" ")
            if fullNameArr.count > 2 && fullNameArr[2] != ""{
                err = "An error occurred when saving the doctor. Please enter a first name and last name separated by a space."
            }
        }
        
        if let adminDocValid = administeringDoctor {
            
        }else {
            err = "Please select an admin doctor to save the bill. Add an admin doctor on the 'Doctor' tab."
        }
        
        return err
    }
    
    func checkInputs() -> String{
        var error = ""
        let keys = [String](codesForBill.keys)
        if keys.isEmpty {
            error = "There were no visit codes for the bill. Please add a visitCode and an ICD code to the bill."
            
        }else if codesForBill[keys[0]]!.isEmpty {
            error = "There were no ICD codes for the bill. Please add an ICD code to the bill"
        }
        
        if patientTextField.text == "" {
            error = "Patient was missing from the bill form. Please add a patient to the bill."
        }
        if patientDOBTextField.text == "" {
            error = "Patient date of birth was missing from the bill form. Please check the form and enter a birth date."
        }
        if doctorTextField.text == "" {
            error = "Doctor was missing from the bill form. Please add a doctor to the bill."
        }
        if siteTextField.text == "" {
            error = "Site was missing from the bill form. Please add a site to the bill"
        }
        if roomTextField.text == "" {
            error = "Room was missing from the bill form. Please add a room to the bill."
        }
        return error
    }
    
    // MARK: - Navigation
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if segue.identifier == "modifierPopover" {                           //Show a list of possible modifiers
            let controller = segue.destinationViewController as! ModifierTableViewController
            controller.modalPresentationStyle = UIModalPresentationStyle.Popover
            controller.popoverPresentationController!.delegate = self

            dbManager.checkDatabaseFileAndOpen()
            controller.modifiers = dbManager.getModifers()
            dbManager.closeDB()
            
            self.modifierTablieViewcontroller = controller

        } else if segue.identifier == "ViewAllBills"{                               //Show all dates that have bills
            let controller = segue.destinationViewController as! BillDatesTableViewController
            
        } else {
            if segue.identifier == "beginICD10Search" {                             //Show the MasterVC for ICD searching
                let controller = segue.destinationViewController as! MasterViewController
                controller.billViewController = self
                controller.visitCodeToAddICDTo = selectedVisitCodeToAddTo!
                controller.billViewController?.visitCodePriority = self.visitCodePriority
                controller.billViewController?.appointmentID = self.appointmentID
                
            }else if segue.identifier == "newBill"{                                 //Begin a new bill by starting with an AdminDoc page
                let controller = segue.destinationViewController as! AdminDocViewController
                controller.adminDoc = self.administeringDoctor
                
            }else if segue.identifier == "visitCodeDescriptionPopover" {            //Show description of visit code
                let popoverViewController = segue.destinationViewController as! visitCodeDetailController
                popoverViewController.modalPresentationStyle = UIModalPresentationStyle.Popover
                popoverViewController.popoverPresentationController!.delegate = self
                
                dbManager.checkDatabaseFileAndOpen()
                popoverViewController.visitCodeDetail = dbManager.getVisitCodeDescription(visitCodePriority[sender!.tag])
                dbManager.closeDB()
                
            }else{//Show a search popover
                
                dbManager.checkDatabaseFileAndOpen()
                let popoverViewController = segue.destinationViewController as! SearchTableViewController
                self.searchTableViewController = popoverViewController
                popoverViewController.modalPresentationStyle = UIModalPresentationStyle.Popover
                popoverViewController.popoverPresentationController!.delegate = self
                
                
                switch segue.identifier! {                                          //Do the initial empty searches
                case "patientSearchPopover":
                    popoverViewController.tupleSearchResults = dbManager.patientSearch(patientTextField!.text!)
                    popoverViewController.searchType = "patient"
                    var absoluteframe = patientTextField!.convertRect(patientTextField!.frame, fromView: self.scrollView)
                    popoverViewController.popoverPresentationController!.sourceRect = CGRectMake(absoluteframe.minX + 60,absoluteframe.minY + 20,0,0)

                case "doctorSearchPopover":
                    popoverViewController.singleDataSearchResults = dbManager.doctorSearch(doctorTextField!.text!, type: 1)
                    popoverViewController.searchType = "doctor"
                    var absoluteframe = doctorTextField!.convertRect(doctorTextField!.frame, fromView: self.scrollView)
                    popoverViewController.popoverPresentationController!.sourceRect = CGRectMake(absoluteframe.minX + 60,absoluteframe.minY + 20,0,0)
                case "siteSearchPopover":
                    popoverViewController.singleDataSearchResults = dbManager.siteSearch(siteTextField.text!)
                    popoverViewController.searchType = "site"
                    var absoluteframe = siteTextField!.convertRect(siteTextField!.frame, fromView: self.scrollView)
                    popoverViewController.popoverPresentationController!.sourceRect = CGRectMake(absoluteframe.minX + 60,absoluteframe.minY + 20,0,0)
                case "roomSearchPopover":
                    popoverViewController.singleDataSearchResults = dbManager.roomSearch(roomTextField.text!)
                    popoverViewController.searchType = "room"
                    var absoluteframe = roomTextField!.convertRect(roomTextField!.frame, fromView: self.scrollView)
                    popoverViewController.popoverPresentationController!.sourceRect = CGRectMake(absoluteframe.minX + 60,absoluteframe.minY + 20,0,0)
                case "cptSearch":
                    popoverViewController.tupleSearchResults = dbManager.codeSearch("C", cptTextFieldText: cptTextField.text!, mcTextFieldText: "", pcTextFieldText: "")
                    var absoluteframe = cptTextField!.convertRect(cptTextField!.frame, fromView: self.scrollView)
                    popoverViewController.popoverPresentationController!.sourceRect = CGRectMake(absoluteframe.minX + 20,absoluteframe.minY + 20,0,0)
                case "mcSearch":
                    popoverViewController.tupleSearchResults = dbManager.codeSearch("M", cptTextFieldText: "", mcTextFieldText: mcTextField.text!, pcTextFieldText: "")
                    var absoluteframe = mcTextField!.convertRect(mcTextField!.frame, fromView: self.scrollView)
                    popoverViewController.popoverPresentationController!.sourceRect = CGRectMake(absoluteframe.minX + 20,absoluteframe.minY + 20,0,0)
                case "pcSearch":
                    popoverViewController.tupleSearchResults = dbManager.codeSearch("P", cptTextFieldText: "", mcTextFieldText: "", pcTextFieldText: pcTextField.text!)
                    var absoluteframe = pcTextField!.convertRect(pcTextField!.frame, fromView: self.scrollView)
                    popoverViewController.popoverPresentationController!.sourceRect = CGRectMake(absoluteframe.minX + 20,absoluteframe.minY + 20,0,0)
                case "adminDoctorSearchPopover": popoverViewController.singleDataSearchResults = dbManager.doctorSearch("", type: 0)
                    popoverViewController.searchType = "adminDoctor"
                var absoluteframe = adminDocButton!.convertRect(adminDocButton!.frame, fromView: self.scrollView)
                popoverViewController.popoverPresentationController!.sourceRect = CGRectMake(absoluteframe.minX,absoluteframe.minY,0,0)
                default:break
                }
                dbManager.closeDB()
            }
        }
    }
    
    override func shouldPerformSegueWithIdentifier(identifier: String?, sender: AnyObject?) -> Bool { //only allow segues that are called programmatically
        return false
    }
    
    // MARK: -  Changes in search fields
    
    
    
    @IBAction func userChangedPatientSearch(sender: UITextField) {
        dbManager.checkDatabaseFileAndOpen()
        
        let patients = dbManager.patientSearch(patientTextField!.text!)                          //retrieve any patients that match the input
        if let patientSearchViewController = searchTableViewController {
            patientSearchViewController.tupleSearchResults = patients
            patientSearchViewController.tableView.reloadData()                                  //update the list in the popup
        }
        dbManager.closeDB()
    }
    
    @IBAction func userChangedDoctorSearch(sender:UITextField){
        dbManager.checkDatabaseFileAndOpen()
        
        let doctors = dbManager.doctorSearch(doctorTextField!.text!, type: 1)
        if let doctorSearchViewController = searchTableViewController {
            doctorSearchViewController.singleDataSearchResults = doctors
            doctorSearchViewController.tableView.reloadData()
        }
        
        dbManager.closeDB()
    }
    
    @IBAction func userChangedVisitCodeSearch(sender:UITextField) {
        
        dbManager.checkDatabaseFileAndOpen()
        
        var visitCodes:[(String,String)] = []
        
        switch sender.tag {
        case 5:
            visitCodes = dbManager.codeSearch("C", cptTextFieldText: cptTextField.text!, mcTextFieldText: "", pcTextFieldText: "")
        case 6:
            visitCodes =  dbManager.codeSearch("M", cptTextFieldText: "", mcTextFieldText: mcTextField.text!, pcTextFieldText: "")
        case 7:
            visitCodes = dbManager.codeSearch("P", cptTextFieldText: "", mcTextFieldText: "", pcTextFieldText: pcTextField.text!)
        default:break
        }
        
        if let visitCodeViewController = searchTableViewController {
            visitCodeViewController.tupleSearchResults = visitCodes
            visitCodeViewController.tableView.reloadData()
        }
        dbManager.closeDB()
    }
    
    @IBAction func userChangedSiteSearch(sender: UITextField) {
        
        dbManager.checkDatabaseFileAndOpen()
        
        let siteResults = dbManager.siteSearch(siteTextField.text!)
        if let siteSearchViewController = searchTableViewController {
            siteSearchViewController.singleDataSearchResults = siteResults
            siteSearchViewController.tableView.reloadData()
        }
        dbManager.closeDB()
    }
    
    @IBAction func userChangedRoomSearch(sender: UITextField) {
        
        dbManager.checkDatabaseFileAndOpen()
        
        let roomResults = dbManager.roomSearch(roomTextField.text!)
        if let roomSearchViewController = searchTableViewController {
            roomSearchViewController.singleDataSearchResults = roomResults
            roomSearchViewController.tableView.reloadData()
        }
        dbManager.closeDB()
    }
    
    // MARK: -  Update search fields
    
    func updatePatient(notification: NSNotification){
        if let controller = searchTableViewController {                             //only update if the searchTableViewController is there
            
            let tuple = controller.selectedTuple
            let (dob,name) = tuple
            self.patientTextField.text = name
            
            self.patientDOBTextField.text = dob
            let pID = getPatientID(name, dateOfBirth: dob)
            
            updateFromPreviousBill(pID)
            self.dismissViewControllerAnimated(true, completion: nil)
            patientTextField.resignFirstResponder()
        }
    }
    
    func updateFromPreviousBill(patientID:Int) {                                    //grab the patients previous information and put it in the bill automatically
        dbManager.checkDatabaseFileAndOpen()
        
        var aptID:Int!
        var placeID:Int!
        var roomID:Int!
        
        let aptQuery = "SELECT aptID, placeID, roomID FROM Appointment WHERE pID=\(patientID) ORDER BY DATE"
        var statement:COpaquePointer = nil
        
        if sqlite3_prepare_v2(dbManager.db, aptQuery, -1, &statement, nil) == SQLITE_OK { //retrieve the most recent ids for the patient
            if sqlite3_step(statement) == SQLITE_ROW {
                aptID = Int(sqlite3_column_int(statement, 0))
                placeID = Int(sqlite3_column_int(statement, 1))
                roomID = Int(sqlite3_column_int(statement, 2))
            } else {
                aptID = -1
                placeID = -1
                roomID = -1
            }
        }
        sqlite3_finalize(statement)
        
        if aptID != -1 && placeID != -1 && roomID != -1 {
            let docQuery = "SELECT dID FROM Has_doc NATURAL JOIN Doctor WHERE aptID=\(aptID) AND Type=1" //retrieve the referring doctor
            var docstatement:COpaquePointer = nil
            var dID:Int?
            if sqlite3_prepare_v2(dbManager.db, docQuery, -1, &docstatement, nil) == SQLITE_OK {
                let result = sqlite3_step(docstatement)
                if result == SQLITE_ROW {
                    dID = Int(sqlite3_column_int(docstatement, 0))
                }
            }
            sqlite3_finalize(docstatement)
            
            doctorTextField.text = dbManager.getDoctorWithID(dID!)
            siteTextField.text = dbManager.getPlaceWithID(placeID)                  //Site
            roomTextField.text = dbManager.getRoomWithID(roomID)                    //Room
            
            var (codesFromDatabase, visitCodePriorityFromDatabase) = dbManager.getVisitCodesForBill(aptID)
            codesForBill = codesFromDatabase
            visitCodePriority = visitCodePriorityFromDatabase                       //Find the correct order from the database
            dbManager.closeDB()
            
            self.codeCollectionView.reloadData()

        }
    }
    
    func updateDoctor(notification: NSNotification) {
        let doctorName = searchTableViewController?.selectedDoctor
        self.doctorTextField.text = doctorName
        self.dismissViewControllerAnimated(true, completion: nil)
        doctorTextField.resignFirstResponder()
    }
    
    func updateAdminDoctor(notification: NSNotification) {
        let doctorName = searchTableViewController?.selectedDoctor
        self.adminDocButton.setTitle(doctorName, forState: UIControlState.Normal)
        self.administeringDoctor = doctorName
        self.dismissViewControllerAnimated(true, completion: nil)
        adminDocButton.resignFirstResponder()
    }
    
    func updateCPT(notification:NSNotification){
        if let controller = searchTableViewController {
            
            let tuple = controller.selectedTuple
            var (code_description,updatedCPTCode) = tuple
            
            
            cptTextField.resignFirstResponder()
            mcTextField.resignFirstResponder()
            pcTextField.resignFirstResponder()
            
            let inBillAlready = codesForBill[code_description] != nil
            
            if !inBillAlready {                                             //only add a new code if it isn't already in the bill
                codesForBill[code_description] = []
                visitCodePriority.append(code_description)
            }
            
            self.dismissViewControllerAnimated(true, completion: nil)
            self.codeCollectionView.reloadData()
            
            
            let defaults = NSUserDefaults.standardUserDefaults()
            let notFirstRun = defaults.boolForKey("notFirstVisitCode")
            print("Is not first run? \(notFirstRun)")
            
            if !defaults.boolForKey("notFirstVisitCode") {
                defaults.setBool(true, forKey: "notFirstVisitCode")
                showAlert("You inserted a visit code!", msg: "Add an ICD-10 code to this visit code by clicking the plus button! If you add more visit codes you can rearrange their priority with the up and down arrows!")
            }
        }
    }
    
    func updateSite(notification:NSNotification) {
        if let controller = searchTableViewController {
            let site = controller.selectedDoctor
            self.siteTextField.text = site
            self.dismissViewControllerAnimated(true, completion: nil)
            self.resignFirstResponder()
        }
    }
    
    func updateRoom(notification:NSNotification) {
        if let controller = searchTableViewController {
            let room = controller.selectedDoctor
            self.roomTextField.text = room
            self.dismissViewControllerAnimated(true, completion: nil)
            self.resignFirstResponder()
        }
    }
    
    func updateModifier(notification:NSNotification){                       //Put the modifier in the Dictionary so the Header cells can display it
        if let controller = modifierTablieViewcontroller {
            let modID = controller.selectedModID
            
            modifierCodes[selectedVisitCodeToAddTo!] = modID!
            self.dismissViewControllerAnimated(true, completion: nil)
            self.resignFirstResponder()
            self.codeCollectionView.reloadData()
            selectedVisitCodeToAddTo = nil
        }
    }
    
    // MARK: - Adding to Database
    
    func addPatientToDatabase(inputPatient:String, email:String) -> String{
        
        
        var (firstName, lastName) = dbManager.split(inputPatient)
        
        var dateOfBirth = patientDOBTextField.text
        dbManager.checkDatabaseFileAndOpen()
        var result = dbManager.addPatientToDatabase(inputPatient, dateOfBirth: dateOfBirth!, email:email)
        dbManager.closeDB()
        return result
    }
    
    func addDoctorToDatabase(inputDoctor:String, email:String) -> String{
        dbManager.checkDatabaseFileAndOpen()
        let result = dbManager.addDoctorToDatabase(inputDoctor, email: email, type: 1)
        dbManager.closeDB()
        return result
    }
    
    func addPlaceOfService(placeInput:String) -> String{
        dbManager.checkDatabaseFileAndOpen()
        let result = dbManager.addPlaceOfService(placeInput)
        dbManager.closeDB()
        return result
    }
    
    func addRoom(roomInput:String) -> String {
        dbManager.checkDatabaseFileAndOpen()
        let result = dbManager.addRoom(roomInput)
        dbManager.closeDB()
        return result
    }
    
    func getPlaceOfServiceID(placeInput:String) -> Int {
        var placeID = 0
        dbManager.checkDatabaseFileAndOpen()
        placeID = dbManager.getPlaceOfServiceID(placeInput)
        dbManager.closeDB()
        return placeID
    }
    
    func getRoomID(roomInput:String) -> Int {
        var roomID = 0
        dbManager.checkDatabaseFileAndOpen()
        roomID = dbManager.getRoomID(roomInput)
        dbManager.closeDB()
        return roomID
    }
    
    func getDoctorID(doctorInput:String) -> Int {
        var dID = 0
        dbManager.checkDatabaseFileAndOpen()
        dID = dbManager.getDoctorID(doctorInput)
        dbManager.closeDB()
        return dID
    }
    
    func getPatientID(patientInput:String, dateOfBirth:String) -> Int {
        
        var pID = 0
        dbManager.checkDatabaseFileAndOpen()
        pID = dbManager.getPatientID(patientInput, dateOfBirth: dateOfBirth)
        dbManager.closeDB()
        return pID
    }
    
    func addAppointmentToDatabase(patientID:Int, date:String, placeID:Int, roomID:Int, codeType:Int, billComplete: Int) -> (Int, String) {
        
        dbManager.checkDatabaseFileAndOpen()
        var (aptID, result) = dbManager.addAppointmentToDatabase(patientID, date: date, placeID: placeID, roomID: roomID, codeType:codeType, billComplete: billComplete)
        dbManager.closeDB()
        return (aptID,result)
    }
    
    func addHasType(aptID:Int, visitCodeText:String, icd10CodeID:Int, visitPriority:Int, icdPriority:Int, extensionCode:String) {
        dbManager.checkDatabaseFileAndOpen()
        dbManager.addHasType(aptID, visitCodeText: visitCodeText, icd10CodeID: icd10CodeID, visitPriority: visitPriority, icdPriority: icdPriority, extensionCode: extensionCode)
        dbManager.closeDB()
    }
    
    func addHasDoc(aptID:Int, dID:Int){
        dbManager.checkDatabaseFileAndOpen()
        dbManager.addHasDoc(aptID, dID: dID)
        dbManager.closeDB()
    }
    
    func showAlert(title:String, msg:String) {
        let controller2 = UIAlertController(title: title,
            message: msg, preferredStyle: .Alert)
        let cancelAction = UIAlertAction(title: "Phew!", style: .Cancel, handler: nil)
        controller2.addAction(cancelAction)
        self.presentViewController(controller2, animated: true, completion: nil)
    }
    
    //MARK: - Collection View
    //NOTE: Collection view runs off of a visitCode priority list (visitCodePriority) for ordering and a dictionary lookup for icd codes.
    //To display, visit code cells are retrieved from the priority list and icd cells are retrieved with the visitcode (using the dictionary codesForBill)
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        let keys = codesForBill.keys
        return keys.count                        //Each visitcode is a new section
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let visitCodeForSection = visitCodePriority[section]
        return codesForBill[visitCodeForSection]!.count             //Each section (visitCode) has a list of ICD codes
    }
    
    func collectionView(collectionView: UICollectionView,layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
            return CGSize(width: 160  , height: 35)                 //A header size needs to be specified for the special layout
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {

        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("CONTENT", forIndexPath: indexPath) as! ICD10Cell
        
        let visitCodeForPriority = visitCodePriority[indexPath.section] //get the item we should display based on priority
        
        let sectionCodes:[(icd10:String, icd9:String, icd10id:Int, extensionCode:String)]  = codesForBill[visitCodeForPriority]! //lookup the icd codes in the dictionary
        
        let (icd10String, icd9String, icd10id, extensionCode) = sectionCodes[indexPath.row]
        
        if codeVersion.on {                                         //determine what type of codes to display (ICD10/ICD9)
            if extensionCode != "" {
                cell.ICDLabel.text = extensionCode
            }else {
                cell.ICDLabel.text = icd10String
            }
        }else {
            cell.ICDLabel.text = icd9String
        }
        
        cell.importanceLabel.text = String(indexPath.row + 1)       //show the priority for the icd codes
        cell.deleteICDButton.tag = indexPath.row
        cell.deleteICDButton.section = indexPath.section
        cell.deleteICDButton.codeToAddTo = visitCodeForPriority

        return cell
    }
    
    func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {
        
        if kind == UICollectionElementKindSectionHeader {
            
            let cell = collectionView.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: "HEADER", forIndexPath: indexPath) as! CodeTokenCollectionViewCell
            
            let visitCodeForPriority = visitCodePriority[indexPath.section] //get the item we should display based on priority
            
            
            let modifierForVisitCode = modifierCodes[visitCodeForPriority]
            cell.visitCodeLabel.text = visitCodeForPriority
            
            if modifierForVisitCode != nil {
                dbManager.checkDatabaseFileAndOpen()
                cell.modifierButton.setTitle(dbManager.getModifierWithID(modifierForVisitCode!), forState: UIControlState.Normal)
                dbManager.closeDB()
            } else {
                cell.modifierButton.setTitle("Mod", forState: UIControlState.Normal)
            }
            
            
            cell.deleteCodeButton.tag = indexPath.section                   //Set the section for the visit code buttons so button actions can
            cell.addICDCodeButton.tag = indexPath.section                   //be linked to the correct visit code
            cell.addICDCodeButton.codeToAddTo = visitCodeForPriority
            cell.shiftDownButton.tag = indexPath.section
            cell.shiftUpButton.tag = indexPath.section
            cell.visitCodeDetailButton.tag = indexPath.section
            cell.modifierButton.tag = indexPath.section
            
            return cell
        }
        abort()
    }
    
    // MARK: - LXReorderableCollectionViewDataSource
    
    func collectionView(collectionView: UICollectionView!, itemAtIndexPath fromIndexPath: NSIndexPath!, didMoveToIndexPath toIndexPath: NSIndexPath!) {
        
        let visitCode = visitCodePriority[toIndexPath.section]
        var icdCodesForKey:[(icd10:String, icd9:String, icd10id:Int, extensionCode:String)] = codesForBill[visitCode]!
        let fromICDCode = icdCodesForKey[fromIndexPath.row]
        
        if fromIndexPath.row < toIndexPath.row {                            //moving a cell to the right
            
            for var i=fromIndexPath.row; i<toIndexPath.row; i++ {           //shift all cells to the new index (left shift)
                icdCodesForKey[i] = icdCodesForKey[i+1]
            }
        }
        
        if fromIndexPath.row > toIndexPath.row {                            //moving a cell to the left
            
            for var i=fromIndexPath.row; i>toIndexPath.row; i = i-1{        //shift all cells down to the new index, to the right
                icdCodesForKey[i] = icdCodesForKey[i-1]
            }
        }
        
        icdCodesForKey[toIndexPath.row] = fromICDCode
        codesForBill[visitCode] = icdCodesForKey
        
        self.codeCollectionView.reloadData()
        
    }
    
    func collectionView(collectionView: UICollectionView!, canMoveItemAtIndexPath indexPath: NSIndexPath!) -> Bool {
        return true
    }
    
    func collectionView(collectionView: UICollectionView!, itemAtIndexPath fromIndexPath: NSIndexPath!, canMoveToIndexPath toIndexPath: NSIndexPath!) -> Bool {
        if toIndexPath.section != fromIndexPath.section{
            return false
        }
        return true
    }
    
    // MARK: - Cell actions
    @IBAction func userClickedDeleteVisitCode(sender: ICDDeleteButton) {
        
        let visitCode = visitCodePriority[sender.tag]
        codesForBill.removeValueForKey(visitCode)
        modifierCodes.removeValueForKey(visitCode)
        
        var deleteResult = visitCodePriority.removeAtIndex(sender.tag)
        self.codeCollectionView.reloadData()
    }
    
    @IBAction func userClickedICD10Add(sender: ICDDeleteButton) {
        selectedVisitCodeToAddTo = sender.codeToAddTo!
        self.performSegueWithIdentifier("beginICD10Search", sender: sender)
    }
    
    
    @IBAction func userClickedDeleteICDCode(sender: ICDDeleteButton) {
        
        let section = sender.section
        let itemInSection = sender.tag
        let visitCode = visitCodePriority[section]
        
        var icdCodes:[(icd10:String, icd9:String, icd10id:Int, extensionCode:String)] = codesForBill[visitCode]!
        icdCodes.removeAtIndex(itemInSection)
        
        codesForBill[sender.codeToAddTo!] = icdCodes
        
        self.codeCollectionView.reloadData()
    }
    
    @IBAction func userClickedModier(sender: ICDDeleteButton) {
        
        let section = sender.tag
        self.selectedVisitCodeToAddTo = visitCodePriority[section]
        self.performSegueWithIdentifier("modifierPopover", sender: self)
    }
    
    @IBAction func shiftVisitCodeUp(sender: ICDDeleteButton) {
        
        if sender.tag > 0 {                         //don't shift up if already at the top
            
            let oldCodeForPriority = visitCodePriority[sender.tag]
            visitCodePriority[sender.tag] = visitCodePriority[sender.tag-1]
            visitCodePriority[sender.tag-1] = oldCodeForPriority
            
            self.codeCollectionView.reloadData()
        }
    }
    
    @IBAction func shiftVisitCodeDown(sender: ICDDeleteButton) {
        
        if sender.tag < (codesForBill.count - 1) {         //don't shift down if already at the bottom
            let codeToMoveDown = visitCodePriority[sender.tag]
            visitCodePriority[sender.tag] = visitCodePriority[sender.tag + 1]
            visitCodePriority[sender.tag + 1] = codeToMoveDown
            
            self.codeCollectionView.reloadData()
        }
    }
    
    func setTabBarVisible(visible:Bool, animated:Bool) {
        
        //* This cannot be called before viewDidLayoutSubviews(), because the frame is not set before this time
        
        // bail if the current state matches the desired state
        if (tabBarIsVisible() == visible) { return }
        
        // get a frame calculation ready
        let frame = self.tabBarController?.tabBar.frame
        let height = frame?.size.height
        let offsetY = (visible ? -height! : height)
        
        // zero duration means no animation
        let duration:NSTimeInterval = (animated ? 0.3 : 0.0)
        
        //  animate the tabBar
        if frame != nil {
            UIView.animateWithDuration(duration) {
                self.tabBarController?.tabBar.frame = CGRectOffset(frame!, 0, offsetY!)
                return
            }
        }
    }
    
    func tabBarIsVisible() ->Bool {
        return self.tabBarController?.tabBar.frame.origin.y < CGRectGetMaxY(self.view.frame)
    }
}