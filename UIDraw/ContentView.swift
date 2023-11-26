//
//  ContentView.swift
//  UIDraw
//
//  Created by Jordan Singer on 11/24/23.
//

import SwiftUI
import PencilKit
import WebKit
import Foundation

let OPENAIKEY = "REPLACE_ME"
let systemPrompt = """
You are an expert web developer who specializes in tailwind css.
A user will provide you with a low-fidelity wireframe of an application.
You will return a single html file that uses HTML, tailwind css, and JavaScript to create a high fidelity website.
Include any extra CSS and JavaScript in the html file.
If you have any images, load them from Unsplash or use solid colored retangles.
The user will provide you with notes in text, arrows, or drawings.
The user may also include images of other websites as style references. Transfer the styles as best as you can, matching fonts / colors / layouts.
They may also provide you with the html of a previous design that they want you to iterate from.
Carry out any changes they request from you.
In the wireframe, the previous design's html will appear as a white rectangle.
Use creative license to make the application more fleshed out.
Use JavaScript modules and unkpkg to import any necessary dependencies.

Respond ONLY with the contents of the html file. Do NOT use markdown or newlines. Your response must start with: "<html>. Do NOT include the following character sequence: ```
"""

struct ContentView: View {
    @State var canvas = PKCanvasView()
    @State var color = Color.primary
    @State var loading = false
    @State var html = ""
    @State var showingPreview = false
    @State var userPrompt = "Prompt"
    
    var body: some View {
        NavigationView {
            VStack {
                if showingPreview {
                    WebView(html: html)
                        .ignoresSafeArea()
                } else {
                    Canvas(canvasView: $canvas)
                        .grayscale(loading ? 1 : 0)
                        .opacity(loading ? 0.5 : 1)
                        .disabled(loading)
                }
            }
                .navigationTitle($userPrompt)
                .toolbarRole(.editor)
                .navigationBarHidden(showingPreview ? true : false)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if !showingPreview {
                            HStack {
                                Button { canvas.undoManager!.undo() } label: {
                                    Image(systemName: "arrow.uturn.backward")
                                }
                                Button { canvas.undoManager!.redo() } label: {
                                    Image(systemName: "arrow.uturn.forward")
                                }
                            }
                            .foregroundStyle(.tertiary)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        if !showingPreview {
                            ColorPicker("Color", selection: $color)
                                .onChange(of: color) { updatedColor in
                                    canvas.tool = PKInkingTool(.pen, color: UIColor(updatedColor))
                                }
                                .labelsHidden()
                        }
                    }
                    
                    ToolbarItemGroup(placement: .bottomBar) {
                        HStack {
//

                            
                            Spacer()
                            Button {
                                build()
                            } label: {
                                if loading {
                                    ProgressView()
                                } else {
                                    if showingPreview {
                                        Text("Edit")
                                    } else {
                                        HStack {
                                            Image(systemName: "sparkles")
                                            Text("Build")
                                        }
                                    }
                                    
                                }
                            }
                            Spacer()
                            
//                            ColorPicker("Color", selection: $color)
//                                .onChange(of: color) { updatedColor in
//                                    canvas.tool = PKInkingTool(.pen, color: UIColor(updatedColor))
//                                }
//                                .labelsHidden()
                        }
                    }
                }
        }
    }
    
    func getCanvasImage() -> String {
        let image = canvas.drawing.image(from: canvas.bounds, scale: CGFloat(1.0))
        let base64 = "data:image/jpeg;base64," + (image.base64 ?? "")
        return base64
    }
    
    func build() {
        withAnimation {
            if showingPreview {
                showingPreview = false
            } else {
                loading = true
                let image = getCanvasImage()
    //            print(image)
                getHtmlFromOpenAI(image: image)
            }
        }
    }
    
    func getHtmlFromOpenAI(image: String) {
        let openAIKey = OPENAIKEY
        if openAIKey == "REPLACE_ME" {
            print("Replace the OPENAIKEY")
            loading = false
            return
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")

        let body = GPT4VCompletionRequest(
            model: "gpt-4-vision-preview",
            temperature: 0,
            max_tokens: 4096,
            messages: [
                    
                Message(role: "system", content: [MessageContent.text(systemPrompt)]), // Replace 'systemPrompt' with the actual system prompt content
                Message(role: "user", content: [MessageContent.imageURL(MessageContent.ImageContent(url: image, detail: "high")), MessageContent.text("Turn this into a single html file using tailwind. The user describes this image as: \(userPrompt)")])
            ]
        )
        
//        print(body)

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print(error)
                return
            }

            guard let data = data else {
                return
            }
            
            print(String(decoding: data, as: UTF8.self))

            do {
                let decodedResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                print("response")
                print(decodedResponse)
                html = decodedResponse.choices.first?.message.content ?? ""
                loading = false
                showingPreview = true
                return
            } catch {
                print("error")
            }
        }

        task.resume()
    }

}

extension UIImage {
    var base64: String? {
        self.jpegData(compressionQuality: 1)?.base64EncodedString()
    }
}

struct GPT4VCompletionRequest: Codable {
    var model: String
    var temperature: Int
    var max_tokens: Int
    var messages: [Message]
}

struct ChatCompletionResponse: Codable {
    var id: String
    var object: String
    var created: Int
    var model: String
    var usage: Usage
    var choices: [Choice]
}

struct Usage: Codable {
    var promptTokens: Int
    var completionTokens: Int
    var totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

struct Choice: Codable {
    var message: GPTMessage
    var finishDetails: FinishDetails
    var index: Int

    enum CodingKeys: String, CodingKey {
        case message
        case finishDetails = "finish_details"
        case index
    }
}

struct GPTMessage: Codable {
    var role: String
    var content: String
}

struct FinishDetails: Codable {
    var type: String
}


enum MessageContent: Codable {
    case text(String)
    case imageURL(ImageContent)

    struct ImageContent: Codable {
        var url: String
        var detail: String
    }

    enum CodingKeys: String, CodingKey {
        case type, text, image_url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image_url":
            let imageURL = try container.decode(ImageContent.self, forKey: .image_url)
            self = .imageURL(imageURL)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Invalid type value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .imageURL(let imageContent):
            try container.encode("image_url", forKey: .type)
            try container.encode(imageContent, forKey: .image_url)
        }
    }
}

struct Message: Codable {
    var role: String
    var content: [MessageContent]
}

struct Canvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .black)
        canvasView.backgroundColor = .clear
        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) { }
}

#Preview {
    ContentView()
}

struct WebView: UIViewRepresentable {
    let html: String
    
    func makeUIView(context: Context) -> WKWebView  {
        let wkwebView = WKWebView()
        wkwebView.loadHTMLString(html, baseURL: nil)
        return wkwebView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
    }
}
