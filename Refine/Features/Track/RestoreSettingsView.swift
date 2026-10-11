import SwiftUI

struct RestoreSettingsView: View {
    @State var settings: RestorationSettings
    var analysis: AudioAnalysis?
    var onRestore: (RestorationSettings) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                highsSection
                intensitySection
                repairSection
                mixSection
                masterSection
                exportSection
            }
            .navigationTitle(settings.engine.rebuildsHighs ? "Restauration" : "Amélioration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.engine.rebuildsHighs ? "Restaurer" : "Améliorer", systemImage: "wand.and.sparkles", role: .confirm) {
                        onRestore(settings)
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Sections, in the order the audio goes through them

    private var highsSection: some View {
        Section {
            Picker("Reconstruction des aigus", selection: $settings.engine) {
                ForEach(RestorationSettings.Engine.allCases) { engine in
                    Label {
                        Text(engine.title)
                        Text(engine.detail).font(.footnote)
                    } icon: {
                        Image(systemName: engine.systemImage)
                    }
                    .tag(engine)
                    .disabled(!engine.isAvailable)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()

            switch settings.engine {
            case .apollo:
                Picker("Calcul", selection: $settings.computeUnits) {
                    ForEach(RestorationSettings.ComputeUnits.allCases) { units in
                        Text(units.title).tag(units)
                    }
                }
                setting("Renforcer les aigus recréés", detail: boostDetail, systemImage: "arrow.up.and.down.text.horizontal",
                        isOn: $settings.extendBandwidth)
            case .signal:
                setting("Combler les trous du spectre", detail: "Adoucit le son « métallique » des MP3 à bas débit.",
                        systemImage: "square.grid.3x3.bottomright.filled", isOn: $settings.fillSpectralHoles)
            case .enhancementsOnly:
                EmptyView()
            }
        } header: {
            Text("Reconstruction des aigus")
        } footer: {
            // Markdown, for the licence and source links.
            Text(LocalizedStringKey(highsFooter))
        }
    }

    private var intensitySection: some View {
        Section {
            Picker("Intensité", selection: $settings.preset) {
                ForEach(RestorationSettings.Preset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        } header: {
            Text("Intensité")
        } footer: {
            Text("Dose les corrections automatiques ci-dessous. « Équilibré » corrige ce que les mesures justifient, « Subtil » en fait environ moitié moins, « Intense » va plus loin sur l'équilibre, le punch et les sifflantes.")
        }
    }

    private var repairSection: some View {
        Section {
            setting("Réparer la saturation", detail: declipDetail, systemImage: "waveform.path.ecg", isOn: $settings.declip)
            setting("Nettoyer le pré-écho", detail: preEchoDetail, systemImage: "waveform.badge.minus",
                    isOn: $settings.restoreTransients)
            setting("Rouvrir l'image stéréo", detail: stereoDetail, systemImage: "arrow.left.and.right",
                    isOn: $settings.restoreStereo)
        } header: {
            Text("Réparations")
        } footer: {
            Text("Chaque réparation n'agit que là où le défaut est présent.")
        }
    }

    private var mixSection: some View {
        Section {
            LabeledContent {
                Text(vocalLevelText)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            } label: {
                Label("Voix", systemImage: "music.microphone")
            }
            Slider(value: $settings.vocalLevel, in: -6...6, step: 1) {
                Text("Voix")
            } minimumValueLabel: {
                Text("En retrait").font(.caption)
            } maximumValueLabel: {
                Text("En avant").font(.caption)
            }
            .accessibilityValue(vocalLevelText)
            setting("Adoucir sifflantes et duretés",
                    detail: "Calme les « s » qui piquent et les pics agressifs des médiums. À essayer à l'écoute : sur certains morceaux, c'est le style.",
                    systemImage: "mouth", isOn: $settings.tameSibilance)
            setting("Grave en mono", detail: monoBassDetail, systemImage: "circle.and.line.horizontal",
                    isOn: $settings.tightenBass)
        } header: {
            Text("Mix")
        } footer: {
            Text("La voix est repérée parce qu'elle est mixée au centre : les instruments placés sur les côtés bougent peu. Ce réglage est appliqué tel quel, quelle que soit l'intensité.")
        }
    }

    private var masterSection: some View {
        Section {
            setting("Équilibre tonal", detail: toneDetail, systemImage: "slider.vertical.3", isOn: $settings.rebalanceTone)
            setting("Punch", detail: punchDetail, systemImage: "bolt", isOn: $settings.restorePunch)
            setting("Volume et crêtes", detail: loudnessDetail, systemImage: "speaker.wave.2", isOn: $settings.adjustLoudness)
        } header: {
            Text("Master")
        } footer: {
            Text("Seuls les défauts détectés sont corrigés : un morceau déjà bien masterisé ressort tel quel.")
        }
    }

    private var exportSection: some View {
        Section {
            Picker("Format", selection: $settings.exportFormat) {
                ForEach(RestorationSettings.ExportFormat.allCases) { format in
                    Text(format.title).tag(format)
                }
            }
            LabeledContent("Résolution", value: settings.exportFormat.summary)
        } header: {
            Text("Export")
        } footer: {
            Text("ALAC et WAV sont sans perte, en qualité CD. AAC 256 kbps est le format d'Apple Music et celui qu'utilisent les AirPods en Bluetooth : 4 à 5 fois plus léger, sans différence audible au casque.")
        }
    }

    private func setting(_ title: String, detail: String, systemImage: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label {
                Text(title)
                Text(detail).font(.footnote)
            } icon: {
                Image(systemName: systemImage)
            }
        }
    }

    // MARK: - Details: what was detected on this track

    private static let nothingToDo = "Rien à corriger sur ce morceau."

    private var highsFooter: String {
        var parts: [String] = []
        switch settings.engine {
        case .apollo:
            parts.append("Apollo, par Kai Li et Yi Luo (Université Tsinghua, Tencent AI Lab), sous licence [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/deed.fr). [Code source et article](https://github.com/JusperLee/Apollo).")
        case .signal, .enhancementsOnly:
            break
        }
        if settings.engine.rebuildsHighs {
            if analysis?.hasMissingHighs == false {
                parts.append("Le spectre de ce morceau est déjà complet : il n'y a rien à reconstruire.")
            } else {
                parts.append("Ce que la compression a supprimé ne peut pas être récupéré à l'identique : Refine le recrée de façon plausible à partir de ce qui reste.")
            }
        }
        parts.append("Tout se passe sur l'iPhone : rien n'est envoyé en ligne.")
        return parts.joined(separator: " ")
    }

    private var boostDetail: String {
        guard let analysis else { return "Ramène les aigus recréés à un niveau naturel." }
        guard analysis.hasMissingHighs else { return Self.nothingToDo }
        return "Ramène les aigus recréés au-delà de \(analysis.cutoffFrequency.kilohertz) à un niveau naturel."
    }

    private var declipDetail: String {
        guard let analysis else { return "Redessine les crêtes écrêtées." }
        return analysis.isClipped ? "Détecté : des crêtes écrêtées, elles seront redessinées." : Self.nothingToDo
    }

    private var preEchoDetail: String {
        if analysis?.verdict == .authenticLossless { return Self.nothingToDo }
        return "Retire le souffle que la compression étale juste avant les percussions."
    }

    private var stereoDetail: String {
        guard let stereo = analysis?.stereo else { return "Rouvre l'image si l'encodeur l'a resserrée dans les aigus." }
        switch stereo.kind {
        case .collapsed:
            return "Détecté : image resserrée au-dessus de \(stereo.collapseFrequency?.kilohertz ?? "6 kHz"), elle sera rouverte."
        case .intact:
            return Self.nothingToDo
        case .mono:
            return "Fichier mono : rien à rouvrir."
        }
    }

    private var monoBassDetail: String {
        if analysis?.stereo?.kind == .mono { return "Fichier mono : le grave est déjà au centre." }
        return "Basse et grosse caisse au centre sous 120 Hz, pour un grave plus net. S'applique à tous les morceaux stéréo."
    }

    private var vocalLevelText: String {
        settings.vocalLevel == 0
            ? "Inchangée"
            : "\(settings.vocalLevel > 0 ? "+" : "−")\(abs(settings.vocalLevel).decibels)"
    }

    private var toneDetail: String {
        guard let tonal = analysis?.tonal else { return "Corrige un son sourd, trop chargé en grave ou confus." }
        let issues = tonal.issues.map { issue in
            switch issue {
            case .dull: "son sourd (\((-tonal.presenceOffset).decibels) de présence en moins qu'un master actuel)"
            case .bright: "aigus plus brillants que la moyenne"
            case .heavyBass: "grave en excès"
            case .thinBass: "grave en retrait"
            case .muddy: "bas-médium chargé"
            }
        }
        guard let last = issues.last else { return Self.nothingToDo }
        let list = issues.count == 1 ? last : issues.dropLast().joined(separator: ", ") + " et " + last
        return "Détecté : \(list). Ce sera corrigé."
    }

    private var punchDetail: String {
        guard let loudness = analysis?.loudness else { return "Rend sa dynamique à un master trop compressé." }
        return loudness.kind == .squashed
            ? "Détecté : master écrasé (crêtes à \(loudness.crest.decibels) du niveau moyen), sa dynamique sera rendue."
            : Self.nothingToDo
    }

    private var loudnessDetail: String {
        let peaks = "Les crêtes sont limitées à −1 dBTP ; désactivé, ni le volume ni les crêtes ne sont touchés."
        guard let loudness = analysis?.loudness else { return "Remonte un morceau trop faible. " + peaks }
        switch loudness.kind {
        case .weak:
            return "Détecté : morceau faible (\(Int(loudness.integrated.rounded())) LUFS), remonté vers \(Int(LoudnessProfile.targetLoudness)) LUFS. " + peaks
        case .squashed where settings.restorePunch:
            return "Baissé un peu pour laisser place au punch. " + peaks
        case .squashed, .natural:
            return "Volume conservé. " + peaks
        }
    }
}

extension RestorationSettings.Engine {
    var detail: String {
        switch self {
        case .apollo: isAvailable
            ? "Réseau de neurones entraîné à restaurer les MP3. Plus lent, plus naturel."
            : "Modèle non inclus dans cette version."
        case .signal: "Instantané : prolonge le spectre en recopiant les harmoniques existantes."
        case .enhancementsOnly: "Garde le spectre d'origine : seules les réparations, le mix et le master s'appliquent."
        }
    }

    var systemImage: String {
        switch self {
        case .signal: "waveform.path"
        case .apollo: "brain"
        case .enhancementsOnly: "waveform"
        }
    }
}
