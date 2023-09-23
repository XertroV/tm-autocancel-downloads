void Main() {
    startnew(MainCoro);
}

CGameDialogs::EDialog lastDialog = CGameDialogs::EDialog::None;

uint lastDownloading;
uint lastUpdating;
bool canceledUnableToDownload = false;

// note, this uses `app.BasicDialogs, and app.Operation_InProgress isn't true when the dialogs are showing.
// exception: when acknowledging failed downloads. For that, we check that lastDownloading was recent.

void MainCoro() {
    auto app = cast<CGameManiaPlanet>(GetApp());
    while (true) {
        yield();
        if (!S_Enabled) {
            sleep(100);
            continue;
        }

        // nothing to cancel if current playground is non-null
        if (app.CurrentPlayground !is null) continue;
        if (app.Editor !is null) continue;

        auto bd = app.BasicDialogs;
        if (lastDialog != bd.Dialog) {
            // warn("New dialog type: " + tostring(bd.Dialog));
            lastDialog = bd.Dialog;
        }

        bool mbHasNonBasicDialog = bd.Dialogs.CurrentFrame !is null;
        bool isWaitMessage = bd.Dialog == CGameDialogs::EDialog::WaitMessage;

        // check non-basic dialogs separately
        if (!isWaitMessage && mbHasNonBasicDialog) {
            CheckNonBasic(app);
            continue;
        }

        // otherwise, if a wait msg is not showing, there's nothing to cancel
        if (!isWaitMessage) continue;

        if (string(bd.WaitMessage_ButtonText) != "Cancel") {
            // print("not cancel: " + bd.WaitMessage_ButtonText);
            continue;
        }

        string label = string(bd.WaitMessage_LabelText);
        bool isUpdating = label.StartsWith("Updating data...");
        bool isDownloading = label.StartsWith("Downloading ");

        if (isWaitMessage) {
            if (isDownloading) lastDownloading = Time::Now;
            if (isUpdating) lastUpdating = Time::Now;
        }

        bool isCarSkin = label.Contains("Skins\\Models\\CarSport\\");
        if (!(isDownloading || isUpdating)) {
            continue;
        }

        bool downloadHasFailed = canceledUnableToDownload && S_CancelAfterFailedDownload;
        canceledUnableToDownload = false;

        // note: we need to check isWaitMessage when in the editor to avoid mb cancelling item saving or things

        bool cancelCarSkin = isCarSkin && S_CancelCarSkins;
        bool cancelUpdating = isUpdating && S_CancelEditorUpdating && isWaitMessage;
        bool cancelAny = isDownloading && S_CancelAnyDownload;
        bool shouldCancel = (cancelCarSkin || cancelUpdating || cancelAny || downloadHasFailed);
        if (!shouldCancel) continue;
        // yield();
        string filename = isUpdating ? "Updating data..." : StripFormatCodes(label).SubStr(20);
        // warn("Cancelling download: " + bd.WaitMessage_LabelText);
        warn("Cancelling download: " + filename);
        bd.WaitMessage_Ok();
        // need 2 yeilds for whatever reason
        yield();
        yield();
        bd.AskYesNo_Yes();
        if (S_ShowNotification) Notify("Auto-cancelled download: " + filename);
    }
}

void CheckNonBasic(CGameCtnApp@ app) {
    canceledUnableToDownload = S_AckFailedDownload && CheckForUnableToDL(app.BasicDialogs);
}

bool CheckForUnableToDL(CGameDialogs@ bd) {
    if (Time::Now - lastDownloading > 2000) return false;
    if (bd.Dialogs is null) return false;
    auto cf = bd.Dialogs.CurrentFrame;
    if (cf is null) return false;
    if (cf.IdName != "FrameMessage") return false;
    try {
        auto c1 = cast<CControlContainer>(cf.Childs[1]); // GridLayout
        auto c2 = cast<CControlContainer>(c1.Childs[0]); // FrameTop
        auto gc = cast<CControlContainer>(c2.Childs[2]); // GridContent

        auto label = cast<CControlLabel>(gc.Childs[1]); // LabelMessage
        auto btnOuter = cast<CGameControlCardGeneric>(gc.Childs[0]); // ButtonOk
        auto btn = cast<CControlButton>(btnOuter.Childs[0]); // ButtonSelection

        if (!c1.IsVisible || !c2.IsVisible || !gc.IsVisible || !btnOuter.IsVisible || !btn.IsVisible || !label.IsVisible) {
            return false;
        }

        if (label.Label.StartsWith("Unable to download data:")) {
            btn.OnAction();
            return true;
        }
    } catch {
        // trace('Error: ' + getExceptionInfo());
    }
    return false;
}

/** Render function called every frame intended only for menu items in `UI`.
*/
void RenderMenu() {
    if (UI::MenuItem(Icons::Ban + " " + Meta::ExecutingPlugin().Name, "", S_Enabled)) {
        S_Enabled = !S_Enabled;
    }
}

void Notify(const string &in msg) {
    UI::ShowNotification(Meta::ExecutingPlugin().Name, msg);
    trace("Notified: " + msg);
}
