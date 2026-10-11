import Foundation

struct RestorationSettings: Codable, Hashable, Sendable {
    enum Preset: String, Codable, CaseIterable, Identifiable, Sendable {
        case subtle, balanced, intense

        var id: Self { self }

        var title: String {
            switch self {
            case .subtle: "Subtil"
            case .balanced: "Équilibré"
            case .intense: "Intense"
            }
        }

        var intensity: Double {
            switch self {
            case .subtle: 0.35
            case .balanced: 0.65
            case .intense: 0.95
            }
        }
    }

    enum ExportFormat: String, Codable, CaseIterable, Identifiable, Sendable {
        case alac, aac, wav

        var id: Self { self }

        var title: String {
            switch self {
            case .alac: "ALAC (Apple Lossless)"
            case .aac: "AAC 256 kbps"
            case .wav: "WAV"
            }
        }

        /// What the file is, as shown next to the export.
        var summary: String {
            switch self {
            case .alac, .wav: "16 bits · 44,1 kHz"
            case .aac: "AAC 256 kbps · 44,1 kHz"
            }
        }

        var codec: AudioCodec {
            switch self {
            case .alac: .alac
            case .aac: .aac
            case .wav: .pcm
            }
        }

        var fileExtension: String {
            switch self {
            case .alac, .aac: "m4a"
            case .wav: "wav"
            }
        }
    }

    /// How the band the codec removed is rebuilt, if at all.
    enum Engine: String, Codable, CaseIterable, Identifiable, Sendable {
        /// Apollo neural network, trained to undo MP3 compression.
        case apollo
        /// Hand-written signal processing: instant, light, conservative.
        case signal
        /// No reconstruction: only the finishing, mix and remastering stages.
        case enhancementsOnly

        var id: Self { self }

        var title: String {
            switch self {
            case .signal: DSPRestorationEngine.name
            case .apollo: ApolloRestorationEngine.name
            case .enhancementsOnly: EnhancementOnlyEngine.name
            }
        }

        var isAvailable: Bool {
            switch self {
            case .signal, .enhancementsOnly: true
            case .apollo: ApolloModel.isBundled
            }
        }

        /// Whether this engine rebuilds the band above the cutoff.
        var rebuildsHighs: Bool { self != .enhancementsOnly }
    }

    /// Which processors Core ML may use for neural engines. The Neural Engine is left out on purpose: it only
    /// computes in float16, which loses too much precision on Apollo's residual sums, and compiling this model for
    /// it takes minutes on first load.
    enum ComputeUnits: String, Codable, CaseIterable, Identifiable, Sendable {
        case gpu, cpu

        var id: Self { self }

        var title: String {
            switch self {
            case .gpu: "GPU (rapide)"
            case .cpu: "Processeur"
            }
        }
    }

    var engine: Engine = ApolloModel.isBundled ? .apollo : .signal
    var computeUnits: ComputeUnits = .gpu
    /// How strongly the automatic corrections act.
    var preset: Preset = .balanced
    /// Apollo: bring the rebuilt highs up to a natural level. The signal engine always does.
    var extendBandwidth = true
    var fillSpectralHoles = true
    var restoreTransients = true
    var restoreStereo = true
    var declip = true
    /// Remaster: correct a dull, boomy or muddy balance.
    var rebalanceTone = true
    /// Remaster: bring the attacks of a squashed master back.
    var restorePunch = true
    /// Remaster: raise a weak master, make room for restored attacks, and limit true peaks to −1 dBTP.
    var adjustLoudness = true
    /// Mix: dB applied to centred content in the voice's band, −6…+6.
    var vocalLevel: Double = 0
    /// Mix: de-esser and dynamic control of harsh mids. Off by default: only the listener can tell style from excess.
    var tameSibilance = false
    /// Mix: mono low end.
    var tightenBass = true
    var exportFormat: ExportFormat = .alac

    init() {}

    var intensity: Double { preset.intensity }

    /// Whether the air stage lifts the band the engine rebuilt.
    var boostsRebuiltHighs: Bool {
        switch engine {
        case .apollo: extendBandwidth
        case .signal: true
        case .enhancementsOnly: false
        }
    }
}

extension RestorationSettings {
    private enum CodingKeys: String, CodingKey {
        case engine, computeUnits, preset, extendBandwidth, fillSpectralHoles, restoreTransients,
             restoreStereo, declip, rebalanceTone, restorePunch, adjustLoudness, vocalLevel, tameSibilance, tightenBass, exportFormat
    }

    /// Missing or unknown keys fall back to defaults, so settings saved by older versions still load.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? container.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        let defaults = RestorationSettings()
        engine = value(.engine, defaults.engine)
        computeUnits = value(.computeUnits, defaults.computeUnits)
        preset = value(.preset, defaults.preset)
        extendBandwidth = value(.extendBandwidth, defaults.extendBandwidth)
        fillSpectralHoles = value(.fillSpectralHoles, defaults.fillSpectralHoles)
        restoreTransients = value(.restoreTransients, defaults.restoreTransients)
        restoreStereo = value(.restoreStereo, defaults.restoreStereo)
        declip = value(.declip, defaults.declip)
        rebalanceTone = value(.rebalanceTone, defaults.rebalanceTone)
        restorePunch = value(.restorePunch, defaults.restorePunch)
        adjustLoudness = value(.adjustLoudness, defaults.adjustLoudness)
        vocalLevel = value(.vocalLevel, defaults.vocalLevel)
        tameSibilance = value(.tameSibilance, defaults.tameSibilance)
        tightenBass = value(.tightenBass, defaults.tightenBass)
        exportFormat = value(.exportFormat, defaults.exportFormat)
        if !engine.isAvailable { engine = .signal }
    }
}
