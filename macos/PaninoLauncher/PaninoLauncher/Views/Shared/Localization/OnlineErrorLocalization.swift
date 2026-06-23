import Foundation

func localizedOnlineError(_ message: String, language: AppLanguage) -> String {
    let lowercased = message.lowercased()
    if lowercased.contains("401") || lowercased.contains("403") || lowercased.contains("auth") || lowercased.contains("rejected the api key") {
        return localizedString(language, english: "The content source rejected the API key. Check the key or switch source.", chinese: "内容渠道拒绝了 API Key。请检查密钥，或切换渠道。", italian: "La fonte ha rifiutato la chiave API. Controllala o cambia fonte.", french: "La source a refusé la clé API. Vérifiez-la ou changez de source.", spanish: "La fuente rechazó la API key. Revísala o cambia de fuente.")
    }
    if lowercased.contains("curseforge_api_key_required") || lowercased.contains("api key") {
        return localizedString(language, english: "CurseForge requires your own API key before browsing. Add it in Settings or switch to Modrinth.", chinese: "CurseForge 需要用户自备 API Key 后才能浏览。请在设置中添加，或切换到 Modrinth。", italian: "CurseForge richiede una chiave API personale. Aggiungila nelle impostazioni o passa a Modrinth.", french: "CurseForge nécessite votre propre clé API. Ajoutez-la dans les réglages ou passez à Modrinth.", spanish: "CurseForge requiere tu propia API key. Añádela en ajustes o cambia a Modrinth.")
    }
    if lowercased.contains("405") || lowercased.contains("method_not_allowed") || lowercased.contains("method not allowed") {
        return localizedString(language, english: "The Core route does not accept this request yet. Restart Core and try again.", chinese: "当前 Core 接口暂不接受这个请求。请重启 Core 后再试。", italian: "La rotta Core non accetta ancora questa richiesta. Riavvia Core e riprova.", french: "La route Core n'accepte pas encore cette requête. Redémarrez Core puis réessayez.", spanish: "La ruta de Core no acepta esta solicitud. Reinicia Core e inténtalo de nuevo.")
    }
    if lowercased.contains("429") || lowercased.contains("rate limit") || lowercased.contains("rate limited") {
        return localizedString(language, english: "The content source is rate limiting requests. Wait a moment or switch source.", chinese: "内容渠道正在限制请求频率。请稍后重试，或切换渠道。", italian: "La fonte sta limitando le richieste. Attendi o cambia fonte.", french: "La source limite les requêtes. Patientez ou changez de source.", spanish: "La fuente está limitando solicitudes. Espera o cambia de fuente.")
    }
    if lowercased.contains("parse") || lowercased.contains("decode") || lowercased.contains("type mismatch") || lowercased.contains("could not parse") {
        return localizedString(language, english: "The content source returned data Panino could not parse.", chinese: "内容渠道返回了 Panino 暂时无法解析的数据。", italian: "La fonte ha restituito dati che Panino non può analizzare.", french: "La source a renvoyé des données que Panino ne peut pas analyser.", spanish: "La fuente devolvió datos que Panino no puede interpretar.")
    }
    if lowercased.contains("500") || lowercased.contains("502") || lowercased.contains("503") || lowercased.contains("upstream") || lowercased.contains("something went wrong") {
        return localizedString(language, english: "The content source is temporarily unavailable. Try again later or switch source.", chinese: "内容渠道暂时不可用。请稍后重试，或切换渠道。", italian: "La fonte è temporaneamente non disponibile. Riprova più tardi o cambia fonte.", french: "La source est temporairement indisponible. Réessayez plus tard ou changez de source.", spanish: "La fuente no está disponible temporalmente. Intenta más tarde o cambia de fuente.")
    }
    if lowercased.contains("network") || lowercased.contains("connection") || lowercased.contains("timeout") || lowercased.contains("proxy") {
        return localizedString(language, english: "Network connection failed. Check proxy/network settings or retry.", chinese: "网络连接失败。请检查代理/网络设置，或重试。", italian: "Connessione di rete fallita. Controlla proxy/rete o riprova.", french: "La connexion réseau a échoué. Vérifiez proxy/réseau ou réessayez.", spanish: "Falló la conexión de red. Revisa proxy/red o reintenta.")
    }
    return message
}
