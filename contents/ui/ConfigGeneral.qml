import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as QtDialogs
import QtQuick.Layouts
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami

KCMUtils.SimpleKCM {
    id: configPage
    property var cfg_launchers
    property var cfg_launchersDefault
    property alias cfg_fillPanel: fillPanel.checked
    property var cfg_fillPanelDefault
    property alias cfg_iconSize: iconSize.value
    property var cfg_iconSizeDefault
    property alias cfg_iconPadding: iconPadding.value
    property var cfg_iconPaddingDefault
    property alias cfg_pinnedSlots: pinnedSlots.value
    property var cfg_pinnedSlotsDefault
    property alias cfg_stackCount: stackCount.value
    property var cfg_stackCountDefault
    property alias cfg_showStackCounter: showStackCounter.checked
    property var cfg_showStackCounterDefault
    property var cfg_stackAssignments
    property var cfg_stackAssignmentsDefault
    property alias cfg_indicatorStyle: indicatorStyle.currentIndex
    property var cfg_indicatorStyleDefault
    property alias cfg_overrideIndicatorColor: overrideIndicatorColor.checked
    property var cfg_overrideIndicatorColorDefault
    property color cfg_indicatorColor
    property var cfg_indicatorColorDefault
    property alias cfg_showPreviews: showPreviews.checked
    property var cfg_showPreviewsDefault
    property alias cfg_previewDelay: previewDelay.value
    property var cfg_previewDelayDefault
    property alias cfg_closeMenuOnTaskHover: closeMenuOnTaskHover.checked
    property var cfg_closeMenuOnTaskHoverDefault
    property alias cfg_scopeScreens: scopeScreens.currentIndex
    property var cfg_scopeScreensDefault
    property alias cfg_scopeDesktops: scopeDesktops.currentIndex
    property var cfg_scopeDesktopsDefault
    property alias cfg_scopeActivities: scopeActivities.currentIndex
    property var cfg_scopeActivitiesDefault
    property alias cfg_groupApplications: groupApplications.checked
    property var cfg_groupApplicationsDefault

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: fillPanel
            Kirigami.FormData.label: "Aspetto:"
            text: "Estendi in tutto lo spazio libero del pannello"
        }
        QQC2.SpinBox {
            id: iconSize
            Kirigami.FormData.label: "Dimensione icone:"
            from: 20
            to: 48
            stepSize: 2
            editable: true
            textFromValue: value => value + " px"
            valueFromText: text => parseInt(text, 10)
        }
        RowLayout {
            Kirigami.FormData.label: "Spazio tra icone:"
            QQC2.Slider {
                id: iconPadding
                Layout.fillWidth: true
                from: 0
                to: 20
                stepSize: 1
                snapMode: QQC2.Slider.SnapAlways
            }
            QQC2.Label {
                text: Math.round(iconPadding.value) + " px"
                Layout.minimumWidth: 42
            }
        }
        QQC2.SpinBox {
            id: pinnedSlots
            Kirigami.FormData.label: "App per stack:"
            from: 4
            to: 12
            editable: true
        }
        QQC2.SpinBox {
            id: stackCount
            Kirigami.FormData.label: "Numero di stack:"
            from: 1
            to: 8
            editable: true
        }
        QQC2.CheckBox {
            id: showStackCounter
            Kirigami.FormData.label: "Contatore stack:"
            text: "Mostra il numero dello stack sulla freccia"
            enabled: stackCount.value > 1
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "Trascina le app fissate col tasto sinistro per riordinarle nello stack corrente. Usa la rotella verso l'alto o il basso sopra le app fissate per passare da uno stack all'altro. Il pulsante + nel menu aggiunge l'app allo stack mostrato. Con un solo stack, la rotella scorre le icone."
        }
        QQC2.ComboBox {
            id: indicatorStyle
            Kirigami.FormData.label: "Indicatore finestre:"
            model: ["Barretta", "Pallino", "Un pallino per finestra"]
        }
        QQC2.CheckBox {
            id: overrideIndicatorColor
            Kirigami.FormData.label: "Colore indicatori:"
            text: "Usa un colore personalizzato"
        }
        RowLayout {
            enabled: overrideIndicatorColor.checked
            Rectangle {
                width: 24
                height: 24
                radius: 4
                border.width: 1
                border.color: Kirigami.Theme.textColor
                color: configPage.cfg_indicatorColor
            }
            QQC2.Button {
                text: "Scegli colore…"
                onClicked: indicatorColorDialog.open()
            }
        }
        QtDialogs.ColorDialog {
            id: indicatorColorDialog
            title: "Colore degli indicatori"
            selectedColor: configPage.cfg_indicatorColor
            onAccepted: configPage.cfg_indicatorColor = selectedColor
        }
        QQC2.CheckBox {
            id: showPreviews
            Kirigami.FormData.label: "Anteprime:"
            text: "Mostra anteprime al passaggio del mouse"
        }
        QQC2.SpinBox {
            id: previewDelay
            Kirigami.FormData.label: "Ritardo anteprima:"
            enabled: showPreviews.checked
            from: 100
            to: 2000
            stepSize: 50
            editable: true
            textFromValue: value => value + " ms"
            valueFromText: text => parseInt(text, 10)
        }
        QQC2.CheckBox {
            id: closeMenuOnTaskHover
            Kirigami.FormData.label: "Menu applicazioni:"
            text: "Chiudi il menu passando sopra un'icona della barra"
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.ComboBox {
            id: scopeScreens
            Kirigami.FormData.label: "Monitor:"
            model: ["Tutti i monitor insieme", "Solo il monitor di questa barra"]
            Layout.fillWidth: true
        }
        QQC2.ComboBox {
            id: scopeDesktops
            Kirigami.FormData.label: "Desktop virtuali:"
            model: ["Tutti i desktop insieme", "Solo il desktop corrente"]
            Layout.fillWidth: true
        }
        QQC2.ComboBox {
            id: scopeActivities
            Kirigami.FormData.label: "Attività:"
            model: ["Tutte le attività insieme", "Solo l'attività corrente"]
            Layout.fillWidth: true
        }
        QQC2.CheckBox {
            id: groupApplications
            Kirigami.FormData.label: "Finestre:"
            text: "Raggruppa le finestre della stessa applicazione"
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "Per barre separate su due o tre monitor, aggiungi questo widget a ogni pannello e seleziona «Solo il monitor di questa barra»."
        }
    }
}
