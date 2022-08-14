/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The sample app's main view controller that manages the scanning process.
*/

import UIKit
import RoomPlan
import RealityKit
import ARKit




class RoomCaptureViewController: UIViewController, RoomCaptureViewDelegate, RoomCaptureSessionDelegate {
 

    
    @IBOutlet var exportButton: UIButton?
    
    @IBOutlet var doneButton: UIBarButtonItem?
    @IBOutlet var cancelButton: UIBarButtonItem?
    
    private var isScanning: Bool = false
    private var objectCount: Int = 0
    
    private var roomCaptureView: RoomCaptureView!
    private var roomCaptureSessionConfig: RoomCaptureSession.Configuration = RoomCaptureSession.Configuration()
    
    private var finalResults: CapturedRoom?
    private var arView: ARView?
    
    private var theVoice = AVSpeechSynthesisVoice(language: "en-US")
    private var theSynth = AVSpeechSynthesizer()
   
   
    private var objectTypeTexts = ["storage","refrigerator", "stove", "bed", "sink","washer", "toilet","bath", "oven","dishwasher","table","sofa","chair","fireplace","television", "stairs"]
    private var labelMesh:[MeshResource] = []
    private var labelMaterial:[Material] = []
    private var fontSize = 0.18
    private var labels: [UUID: ModelEntity] = [:]
    private var openingDistances: [UUID: ModelEntity] = [:]
    private var openingDistanceTexts: [UUID:String] = [:]
    private var DistanceFontSize = 0.1
   
    // JCV test from discussion forum https://developer.apple.com/forums/thread/707803
  /*  var arSceneView: ARSCNView!
     var session:RoomCaptureSession!
*/
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up after loading the view.
        setupRoomCaptureView()
        // just to prepare for TTS
        //theVoice = AVSpeechSynthesisVoice(language: "en-US")!
        // unelegant hack: found that the ARView element is the first subview of the roomcaptureview
        arView = (self.roomCaptureView.subviews[0] as! ARView)
       
        let mirror = Mirror(reflecting: CapturedRoom.Object.Category.self )
        //let l = CapturedRoom.Object.Category.init(from: self)
        //print(String(reflecting: l))
        //let associated = mirror.children.first
       // let values = Mirror(reflecting: associated!.value).children
       //             var valuesArray = [String: Any]()
        //for child in EnumSequence<CapturedRoom.Object.Category>() {print(child)}
      //  mirror.children.forEach { child in
       //     print("Found child '\(child.label ?? "")' with value '\(child.value)'")
        //}
        for text in objectTypeTexts
        {
            labelMesh.append(  MeshResource.generateText(text, extrusionDepth: 0.015, font: .init(name: "Helvetica", size: fontSize)!, containerFrame: .zero, alignment: .center, lineBreakMode: .byWordWrapping))
            labelMaterial.append(UnlitMaterial(color: .random))
            //labelMaterial.append(SimpleMaterial(color: .random, isMetallic: false))
           
        }
    }
    
    // JCV provide some feedback (auditory)
    
    func captureSession(_ session: RoomCaptureSession, didAdd room: CapturedRoom) {
        //play a sound ?
       // print(self.ARWorldTrackingConfiguration())
       // print(session.arSession.)
               //.detectionObjects )
       
        if  room.objects.count > 0
        {
           // new objects were found! - play a shound
            //AudioServicesPlaySystemSound( 1057)
            for o in room.objects {
                giveFeedbackObject(o: o) // text to speech & add labels to arkit scene
            }
          //  print("piep")
          // print(arView?.scene)
        }
       /* else
        {
            print("doors:\(room.doors.count)");
            print("openings:\(room.openings.count)");
            print("windows:\(room.windows.count)");
        }
        */
        //{//AudioServicesPlaySystemSound(1104) // play short tick
            /* due to error in ios beta 4, this does not work.
            giveFeedbackRoom(count: room.windows.count, type:"window")
            giveFeedbackRoom(count: room.doors.count,type:"door")
            giveFeedbackRoom(count: room.openings.count, type:"opening")
             */
            /* might need to revise this */
         //   for o in room.openings {
          //      drawOpening(o: o) // text to speech & add labels to arkit scene
         //   }
          //  for d in room.doors {
          //      drawOpening(o: d) // text to speech & add labels to arkit scene
         //   }
            //
        //}
    }
    
    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        
            // fix for beta 4, should work in the didAdd and didChange delegate but that seems to be broken
            /* might need to revise this */
            for o in room.openings {
                drawOpening(o: o) // text to speech & add labels to arkit scene
            }
            for d in room.doors {
                drawOpening(o: d) // text to speech & add labels to arkit scene
            }
            //
       
    }
    func giveFeedbackRoom(count: Int, type: String)
    {
        var speak = ""
        if count == 0 {return}
        if count>1 { speak = "\(count) \(type)s"} else {speak = type}
        talk(aString: speak)
    }
    
    func drawOpening(o: CapturedRoom.Surface)
    {
        // check if opening already exists, if so: only update and leave routine
        if  openingDistances[o.identifier] != nil { updateOpening(o: o); return}
        // we will create a new textEntity anchor
        // to keep runtime happy, do this as an async process (otherwise will crash at generateText() call).
        DispatchQueue.main.async {
            let dist = sqrt(o.dimensions.x * o.dimensions.x  + o.dimensions.z * o.dimensions.z)
            let text = "<--" + String(format: "%.2f", dist) + "-->"
            let textModel = MeshResource.generateText(text, extrusionDepth: 0.015, font: .init(name: "Helvetica", size: self.DistanceFontSize)!, containerFrame: .zero, alignment: .center, lineBreakMode: .byWordWrapping)
            let textEntity = ModelEntity(mesh:  textModel,
                                         materials: [UnlitMaterial(color: .white)])
            self.updateOpeningPosition(textEntity: textEntity, o: o)

            // add to current ARView scene graph
            let a = self.arView?.scene.anchors[0]
            a?.addChild(textEntity )
            // housekeeping
            self.openingDistances[o.identifier] = textEntity
            self.openingDistanceTexts[o.identifier] = text
            
        }
    }
    func updateOpeningPosition(textEntity: ModelEntity, o:CapturedRoom.Surface) {
        textEntity.transform = Transform(matrix:  o.transform )
        //print (textEntity?.transform)
        textEntity.setOrientation(simd_quatf(angle: -90 * .pi/180, axis: [1,0,0]), relativeTo: textEntity)
        //textEntity?.transform.rotation = simd_quatf(angle: -90 * .pi/180, axis: [1,0,0])
        
        // center the text - already assigned to the textentity model mesh
        textEntity.transform.translation.x -= (textEntity.model?.mesh.bounds.center.x)!
        // textEntity?.transform.translation.z = 0
        
        // move to ground level
        textEntity.transform.translation.y -= o.dimensions.y/2

    }
    func updateOpening(o: CapturedRoom.Surface)
    {
        DispatchQueue.main.async {
            let textEntity = self.openingDistances[o.identifier]
        if textEntity == nil {return} // Just to be sure.
            let dist = sqrt(o.dimensions.x * o.dimensions.x  + o.dimensions.z * o.dimensions.z)
            let text = String(format: "%.2f", dist) + "m"
            //let text = "<--\(dist, specifier: "%.2f")-->"
            // only update when text is different
            if (text != self.openingDistanceTexts[o.identifier])
            {
                let textModel = MeshResource.generateText(text, extrusionDepth: 0.01, font: .init(name: "Helvetica", size: self.DistanceFontSize)!, containerFrame: .zero, alignment: .center, lineBreakMode: .byWordWrapping)
                
                textEntity?.model?.mesh = textModel ///.replace(  with: textModel.contents)
                self.updateOpeningPosition(textEntity: textEntity!, o: o)

                // housekeeping (necessary due to errors in beta 4)
                self.openingDistanceTexts[o.identifier] = text
            }
            
        }
        
    }
    func giveFeedbackObject(o: CapturedRoom.Object)
    {
        if labels[o.identifier] != nil {updateObjectPosition(o: o); return}
        DispatchQueue.main.async {
            var speak = "";
            // convert object type to text
            speak = String(describing: o.category)
            
            self.talk(aString: speak)
            // HACK - add dscription to  scene
            if o.confidence  == .low { return }
            //
            let labelIndex = self.objectTypeTexts.firstIndex(of:speak)!
            let textEntity = ModelEntity(mesh:  self.labelMesh[labelIndex],
                                         materials: [self.labelMaterial[labelIndex]])
            
            // add this textEntity to the current RealityKit scene
            // hack: just add it to the first anchor in the scene - seems to work....
            let a = self.arView?.scene.anchors[0]
            a?.addChild(textEntity )
            // add this to the labels dictionary for updating position later
            self.labels[o.identifier] = textEntity
            
            self.updateObjectPosition(o: o)
            
          
        }
    }
    
    func talk(aString:String)
    {   // TTS sample, uses AVSpeech library
        let utterance = AVSpeechUtterance(string: aString)
        utterance.voice = theVoice
        theSynth.speak(utterance)
    }
    // JCV provide some feedback (auditory)
    func captureSession(_ session: RoomCaptureSession, didChange room: CapturedRoom) {
        for o in room.objects {
            // retrieve respective label (from dictionary)
            updateObjectPosition(o:o)
        } // for
        // check to see wether anything else was changed than objects (beta 4 error?)
       // if room.objects.isEmpty { AudioServicesPlaySystemSound(1104) }
        /* beta need to revise this */
        /*
        for o in room.openings {
            updateOpening(o: o) //  add labels to arkit scene
        }
        for d in room.doors {
            updateOpening(o: d) //  add labels to arkit scene
        }
         */
    }
    func updateObjectPosition(o: CapturedRoom.Object) {
        let textEntity = labels[o.identifier]
        if textEntity == nil {return}
        // lets update all the label position based on adapted dimensions/location
        textEntity?.transform = Transform(matrix: o.transform )
        // center the text
        let txtCategory = String(describing: o.category)
        let t = textEntity?.transform.translation
        if txtCategory == "storage" {print( t)}
        let labelIndex = objectTypeTexts.firstIndex(of:txtCategory)!
        textEntity?.transform.translation.x -= labelMesh[labelIndex].bounds.center.x
        if (txtCategory != "chair" ) && (txtCategory != "stairs") {
            textEntity?.transform.translation.y += (o.dimensions.y)/2.0
        }
        if (txtCategory == "table") || (txtCategory == "bed")
        {
            textEntity?.setOrientation(simd_quatf(angle: -90 * .pi/180, axis: [1,0,0]), relativeTo: textEntity)
        }
    }
    

    func captureSession(_ session: RoomCaptureSession, didRemove room: CapturedRoom) {
        // remove labels of objects or distances if applicable
        for o in room.objects {
            let textEntity = labels[o.identifier]
            if textEntity != nil {
                let a = self.arView?.scene.anchors[0]
                a?.removeChild(textEntity! )
                // should also remove dictionary item but that is for latr
            }
        }
        /* */
            for o in room.openings {
                let textEntity = openingDistances[o.identifier]
                if textEntity != nil {
                    let a = self.arView?.scene.anchors[0]
                    a?.removeChild(textEntity! )
                    // should also remove dictionary item but that is for latr
                }
            }
        for o in room.doors {
            let textEntity = openingDistances[o.identifier]
            if textEntity != nil {
                let a = self.arView?.scene.anchors[0]
                a?.removeChild(textEntity! )
                // should also remove dictionary item but that is for latr
            }
        }
        // */
    }

    //JCV  when user instruction is provided, also give sound or buzz
    func captureSession(_ session: RoomCaptureSession, didProvide instruction: RoomCaptureSession.Instruction ) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    // JCV from discussion board
    func captureSession(_ session: RoomCaptureSession, didStartWith configuration: RoomCaptureSession.Configuration){
        
        }
    
    private func setupRoomCaptureView() {
        roomCaptureView = RoomCaptureView(frame: view.bounds)
        roomCaptureView.captureSession.delegate = self
        roomCaptureView.delegate = self
        
        view.insertSubview(roomCaptureView, at: 0)

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        startSession()
    }
    
    override func viewWillDisappear(_ flag: Bool) {
        super.viewWillDisappear(flag)
        stopSession()
    }
    
    private func startSession() {
        isScanning = true
        // test code session.run(configuration: roomCaptureSessionConfig)
        roomCaptureView?.captureSession.run(configuration: roomCaptureSessionConfig)
        
        setActiveNavBar()
    }
    
    private func stopSession() {
        isScanning = false
        roomCaptureView?.captureSession.stop()
        setCompleteNavBar()
    }
    
    // Decide to post-process and show the final results.
    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        if (error != nil) {return false}
    //    print("Error = \(error)")
        return true
    }
    
    // Access the final post-processed results.
    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        finalResults = processedResult
        if (error != nil)
         {self.doneButton?.title = error.debugDescription} else
        {self.doneButton?.title = "Done" }
    }
    
    @IBAction func doneScanning(_ sender: UIBarButtonItem) {
        if isScanning { stopSession();AudioServicesPlaySystemSound(1108)} else { cancelScanning(sender) }
    }

    @IBAction func cancelScanning(_ sender: UIBarButtonItem) {
        navigationController?.dismiss(animated: true)
    }
    
    @IBAction func exportResults(_ sender: UIButton) {
        let destinationURL = FileManager.default.temporaryDirectory.appending(path: "Room.usdz")
        do {
            try finalResults?.export(to: destinationURL)
            
            let activityVC = UIActivityViewController(activityItems: [destinationURL], applicationActivities: nil)
            activityVC.modalPresentationStyle = .popover
            
            present(activityVC, animated: true, completion: nil)
            if let popOver = activityVC.popoverPresentationController {
                popOver.sourceView = self.exportButton
            }
        } catch {
            print("Error = \(error)")
        }
    }
    
    private func setActiveNavBar() {
        UIView.animate(withDuration: 1.0, animations: {
            self.cancelButton?.tintColor = .white
            self.doneButton?.tintColor = .white
            self.exportButton?.alpha = 0.0
        }, completion: { complete in
            self.exportButton?.isHidden = true
        })
    }
    
    private func setCompleteNavBar() {
        self.exportButton?.isHidden = false
        UIView.animate(withDuration: 1.0) {
            self.cancelButton?.tintColor = .systemBlue
            self.doneButton?.tintColor = .systemBlue
            //self.doneButton?.title = "Done"
            self.exportButton?.alpha = 1.0
        }
    }
}
// helper function to generate random colors
extension UIColor {
    static var random: UIColor {
        return .init(hue: .random(in: 0...1), saturation: 1, brightness: 1, alpha: 1)
    }
}
