import Foundation

struct ClaudeNotesGenerator: NotesGenerator {

    let apiKey: String

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-4-6"

    func generateNotes(from transcript: TranscriptData) async throws -> NotesData {
        guard !apiKey.isEmpty else { throw GeneratorError.missingAPIKey }

        let prompt = buildPrompt(transcript: transcript.fullText)

        // Use tool-use to guarantee structured JSON output.
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "tools": [notesTool],
            "tool_choice": ["type": "tool", "name": "create_meeting_notes"],
            "messages": [["role": "user", "content": prompt]]
        ]

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue(apiKey,          forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01",    forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw GeneratorError.invalidResponse("no HTTP response") }
        guard http.statusCode == 200 else { throw GeneratorError.httpError(http.statusCode) }

        return try parseResponse(data)
    }

    // MARK: - Helpers

    private func buildPrompt(transcript: String) -> String {
        """
        Summarize this meeting transcript. Call create_meeting_notes with the result.

        Prioritize action items — they appear first in the user's view, so extract them carefully.
        Only include items that are explicitly stated as something to do; do not invent.

        - title: under 60 chars, descriptive of the meeting's main topic
        - actionItems: explicit todos; include owner and due if stated, leave null if not
        - summary: 2–3 sentences of what was discussed
        - keyPoints: bullet-worthy discussion points (not action items)

        Transcript:
        \(transcript)
        """
    }

    private var notesTool: [String: Any] {
        [
            "name": "create_meeting_notes",
            "description": "Creates structured meeting notes from a transcript.",
            "input_schema": [
                "type": "object",
                "required": ["title", "summary", "keyPoints", "actionItems"],
                "properties": [
                    "title": ["type": "string"],
                    "summary": ["type": "string"],
                    "keyPoints": ["type": "array", "items": ["type": "string"]],
                    "actionItems": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "required": ["text", "done"],
                            "properties": [
                                "text":  ["type": "string"],
                                "owner": ["type": ["string", "null"]],
                                "due":   ["type": ["string", "null"]],
                                "done":  ["type": "boolean"],
                                "externalRef": ["type": ["string", "null"]]
                            ]
                        ]
                    ]
                ]
            ]
        ]
    }

    private func parseResponse(_ data: Data) throws -> NotesData {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = obj["content"] as? [[String: Any]],
              let toolUse = content.first(where: { $0["type"] as? String == "tool_use" }),
              let input = toolUse["input"] as? [String: Any] else {
            let preview = String(data: data.prefix(200), encoding: .utf8) ?? ""
            throw GeneratorError.invalidResponse(preview)
        }

        let inputData = try JSONSerialization.data(withJSONObject: input)
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(NotesData.self, from: inputData)
        } catch {
            let preview = String(data: inputData.prefix(300), encoding: .utf8) ?? ""
            throw GeneratorError.invalidResponse("decode failed: \(error.localizedDescription) — input: \(preview)")
        }
    }
}
