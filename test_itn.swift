import Foundation

func test(lang: String, text: String) {
    let locale = lang == "de" ? Locale(identifier: "de_DE") : Locale(identifier: "en_US")
    let formatter = NumberFormatter()
    formatter.numberStyle = .spellOut
    formatter.locale = locale
    
    if let number = formatter.number(from: text.lowercased()) {
        print("\(lang) '\(text)' -> \(number)")
    } else {
        print("\(lang) '\(text)' -> nil")
    }
}

test(lang: "de", text: "ein\u{00AD}hundert")
test(lang: "de", text: "ein-hundert")
test(lang: "de", text: "ein hundert")
test(lang: "de", text: "einhundert")
test(lang: "en", text: "one hundred twenty-three")
test(lang: "en", text: "one hundred twenty three")
