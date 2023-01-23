void Main() {
    startnew(MainCoro);
}

CGameDialogs::EDialog lastDialog = CGameDialogs::EDialog::None;

// note, this uses `app.BasicDialogs, and app.Operation_InProgress isn't true when the dialogs are showing.

void MainCoro() {
    auto app = cast<CGameManiaPlanet>(GetApp());
    while (true) {
        yield();
        if (!S_Enabled) {
            sleep(100);
            continue;
        }
        auto bd = app.BasicDialogs;
        if (lastDialog != bd.Dialog) {
            // warn("New dialog type: " + tostring(bd.Dialog));
            lastDialog = bd.Dialog;
        }
        if (bd.Dialog != CGameDialogs::EDialog::WaitMessage) continue;
        if (string(bd.WaitMessage_ButtonText) != "Cancel") {
            // print("not cancel: " + bd.WaitMessage_ButtonText);
            continue;
        }
        string label = string(bd.WaitMessage_LabelText);
        bool isUpdating = label.StartsWith("Updating data...");
        bool isDownloading = label.StartsWith("Downloading ");
        bool isCarSkin = label.Contains("Skins\\Models\\CarSport\\");
        if (!(isDownloading || isUpdating)) {
            continue;
        }
        bool cancelCarSkin = isCarSkin && S_CancelCarSkins;
        bool cancelUpdating = isUpdating && S_CancelEditorUpdating;
        bool cancelAny = isDownloading && S_CancelAnyDownload;
        bool shouldCancel = (cancelCarSkin || cancelUpdating || cancelAny);
        if (!shouldCancel) continue;
        yield();
        string filename = isUpdating ? "Updating data..." : StripFormatCodes(label).SubStr(20);
        // warn("Cancelling download: " + bd.WaitMessage_LabelText);
        warn("Cancelling download: " + filename);
        bd.WaitMessage_Ok();
        sleep(50);
        bd.AskYesNo_Yes();
        if (S_ShowNotification) Notify("Auto-cancelled download: " + filename);
    }
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
