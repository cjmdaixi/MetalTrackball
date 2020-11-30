//
//  SwiftUIView.swift
//  ModelViewer
//
//  Created by 陈锦明 on 2020/11/24.
//

import SwiftUI

struct SwiftUIView: View {
    @EnvironmentObject var globalVariables: GlobalVariables
    
    var body: some View {
        VStack(spacing: 15) {
            Button(action:{
                if let plyUrl = Bundle.main.url(forResource: "UpperJaw", withExtension: "ply"){
                    globalVariables.renderer.load(ply: plyUrl)
                }
                
            }){
                Text("Upper Jaw")
            }
            
            
            Button(action:{
                if let plyUrl = Bundle.main.url(forResource: "OrigionLower", withExtension: "ply"){
                    globalVariables.renderer.load(ply: plyUrl)
                }
                
            }){
                Text("OrigionLower")
            }
            
            Button(action:{
                if let plyUrl = Bundle.main.url(forResource: "OrigionUpper", withExtension: "ply"){
                    globalVariables.renderer.load(ply: plyUrl)
                }
                
            }){
                Text("OrigionUpper")
            }
            
            Button(action:{
                globalVariables.renderer.streaming()
            }){
                Text("Streaming")
            }
        }
        .lineSpacing(/*@START_MENU_TOKEN@*/10.0/*@END_MENU_TOKEN@*/)
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUIView()
    }
}
