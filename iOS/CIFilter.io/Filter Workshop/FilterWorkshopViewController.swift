//
//  FilterWorkshopViewController.swift
//  CIFilter.io
//
//  Created by Noah Gilmore on 12/8/18.
//  Copyright © 2018 Noah Gilmore. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import MobileCoreServices

final class FilterWorkshopViewController: UIViewController {
    private let bag = DisposeBag()
    private let applicator = AsyncFilterApplicator()
    private let exporter = FilterApplicationExporter()
    private lazy var workshopView: FilterWorkshopView = {
        return FilterWorkshopView(applicator: self.applicator)
    }()
    private var currentImage: RenderingResult? = nil
    private let filter: FilterInfo
    private var shareItem: UIBarButtonItem! = nil
    private var exportItem: UIBarButtonItem! = nil
    private var inputImageCurrentlySelecting: String? = nil
    private var currentGeneratedImageParmaeters: [String: Any]? = nil

    init(filter: FilterInfo) {
        self.filter = filter
        super.init(nibName: nil, bundle: nil)
        self.title = filter.name

        self.shareItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(didTapShareButton))
        self.shareItem.isEnabled = false
        self.exportItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapExportButton))
        self.exportItem.isEnabled = false

        #if DEBUG
            self.navigationItem.rightBarButtonItems = [exportItem, shareItem]
        #else
            self.navigationItem.rightBarButtonItem = shareItem
        #endif

        applicator.events.observeOn(MainScheduler.instance).subscribe(onNext: { event in
            guard case let .generationCompleted(image, _, parameters) = event else {
                self.shareItem.isEnabled = false
                self.exportItem.isEnabled = false
                return
            }
            self.shareItem.isEnabled = true
            self.exportItem.isEnabled = true
            self.currentImage = image
            self.currentGeneratedImageParmaeters = parameters
        }).disposed(by: bag)

        workshopView.didChooseAddImage.subscribe(onNext: { paramName, sourceView in
            self.inputImageCurrentlySelecting = paramName
            let vc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            vc.addAction(UIAlertAction(title: "Take photo", style: .default, handler: { [weak self] _ in
                let picker = UIImagePickerController()
                picker.sourceType = .camera
                picker.mediaTypes = [kUTTypeImage as String]
                picker.delegate = self
                self?.present(picker, animated: true, completion: nil)
            }))
            vc.addAction(UIAlertAction(title: "Select from library", style: .default, handler: { [weak self] _ in
                let picker = UIImagePickerController()
                picker.sourceType = .photoLibrary
                picker.mediaTypes = [kUTTypeImage as String]
                picker.delegate = self
                self?.present(picker, animated: true, completion: nil)
            }))
            vc.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
            vc.popoverPresentationController?.sourceView = sourceView
            vc.popoverPresentationController?.sourceRect = sourceView.bounds
            self.present(vc, animated: true, completion: nil)
        }).disposed(by: bag)
    }

    @objc private func didTapShareButton() {
        guard let image = currentImage else { return }
        let shareController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        shareController.modalPresentationStyle = .popover
        shareController.popoverPresentationController?.barButtonItem = self.shareItem
        self.present(shareController, animated: true)
    }

    @objc private func didTapExportButton() {
        guard let outputImage = self.currentImage, let parameters = self.currentGeneratedImageParmaeters else {
            return
        }
        exporter.export(outputImage: outputImage, parameters: parameters, filterName: self.filter.name)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        self.view = workshopView
        workshopView.set(filter: self.filter)
    }
}

extension FilterWorkshopViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        // TODO: Errors for these
        guard let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else { return }
        guard let currentlySelectingParamName = self.inputImageCurrentlySelecting else { return }
        self.workshopView.setImage(originalImage, forParameterNamed: currentlySelectingParamName)
        self.dismiss(animated: true, completion: nil)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
}
