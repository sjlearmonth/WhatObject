//
//  ViewController.swift
//  WhatObject
//
//  Created by Stephen Learmonth on 19/05/2022.
//

import UIKit
import CoreML
import Vision
import Alamofire
import SwiftyJSON
import SDWebImage

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    let wikipediaURL = "http://en.wikipedia.org/w/api.php"
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var extractLabel: UILabel!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    let imagePicker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        
        activityIndicator.stopAnimating()
        
    }
    
    @IBAction func cameraTapped(_ sender: UIBarButtonItem) {
        
        present(imagePicker, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let userPickedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            
            guard let convertedCIImage = CIImage(image: userPickedImage) else {
                fatalError("Cannot convert to CIImage")
            }
            
            detect(image: convertedCIImage)
            
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    private func detect(image: CIImage) {
        let config = MLModelConfiguration()
        
        guard let coreMLModel = try? MobileNetV2(configuration: config),
              let model = try? VNCoreMLModel(for: coreMLModel.model) else {
            fatalError("Loading CoreML Model failed.")
        }
        
        let request = VNCoreMLRequest(model: model) { request, error in
            guard let classification = request.results?.first as? VNClassificationObservation else {
                fatalError("Could not classify image.")
            }
            
            self.title = classification.identifier.capitalized
            
            self.requestInfo(objectName: classification.identifier)
            
        }
        
        let handler = VNImageRequestHandler(ciImage: image)
        
        do {
            try handler.perform([request])
        } catch {
            print(error)
        }
    }
    
    private func requestInfo(objectName: String) {
        
        activityIndicator.startAnimating()
        
        let outerParameters  : [String : String] = [
            "format" : "json",
            "action" : "query",
            "prop" : "extracts|images",
            "imlimit" : "max",
            "exintro" : "",
            "explaintext" : "",
            "titles": objectName,
            "indexpageids" : "",
            "redirects" : "1"]
        
        Alamofire.request(wikipediaURL, method: .get, parameters: outerParameters).responseJSON { response in
            if response.result.isSuccess {
                
                let objectJSON : JSON = JSON(response.result.value as Any)
                let pageId = objectJSON["query"]["pageids"][0].stringValue
                let objectDescription = objectJSON["query"]["pages"][pageId]["extract"].stringValue
                
                var imageTitle = ""
                guard let objectImageDicts = objectJSON["query"]["pages"][pageId]["images"].arrayObject as? [[String:Any]] else { return }
                let subStrings = objectName.split(separator: " ")
                
            outerloop: for dict in objectImageDicts {
                if let title = dict["title"] as? String {
                    for subString in subStrings {
                        if let _ = title.range(of: String(subString), options: .caseInsensitive) {
                            imageTitle = title
                            break outerloop
                        }
                    }
                }
            }
                
                if imageTitle != "" {
                    
                    let innerParameters : [String : String] =
                    ["format" : "json",
                     "action" : "query",
                     "prop" : "imageinfo",
                     "titles" : imageTitle,
                     "iiprop" : "url"]
                    
                    Alamofire.request(self.wikipediaURL, method: .get, parameters: innerParameters).responseJSON { response in
                        
                        if response.result.isSuccess {
                            
                            let objectJSON : JSON = JSON(response.result.value as Any)
                            let imageURL = objectJSON["query"]["pages"]["-1"]["imageinfo"][0]["url"].stringValue
                            
                            self.activityIndicator.stopAnimating()
                            
                            self.imageView.sd_setImage(with: URL(string: imageURL))
                        }
                    }
                } else {
                    
                    self.activityIndicator.stopAnimating()
                    
                    self.imageView.image = UIImage(systemName: "questionmark.app")
                }
                
                self.extractLabel.text = objectDescription
                
            }
        }
    }
}
