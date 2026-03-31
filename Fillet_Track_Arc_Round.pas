Const
    MyPI = 3.14159265358979323846;

// --- Grundlegende Mathe-Funktionen ---
Function ArcTan2(Y, X: Double): Double;
Begin
    If X > 0.0 Then Result := ArcTan(Y/X)
    Else If X < 0.0 Then Begin
        If Y >= 0.0 Then Result := ArcTan(Y/X) + MyPI
        Else Result := ArcTan(Y/X) - MyPI;
    End
    Else If Y > 0.0 Then Result := MyPI / 2.0
    Else If Y < 0.0 Then Result := -MyPI / 2.0
    Else Result := 0.0;
End;

Function ArcCos(X: Double): Double;
Begin
    If X >= 1.0 Then Result := 0.0
    Else If X <= -1.0 Then Result := MyPI
    Else Result := (MyPI / 2.0) - ArcTan(X / Sqrt(1.0 - X*X));
End;

Function Dist(X1, Y1, X2, Y2: Double): Double;
Begin
    Result := Sqrt((X1-X2)*(X1-X2) + (Y1-Y2)*(Y1-Y2));
End;

Function IsAngleBetween(a, s, e: Double): Boolean;
Var span, d1: Double;
Begin
    span := e - s;
    If span < 0 Then span := span + 360.0;
    d1 := a - s;
    If d1 < 0 Then d1 := d1 + 360.0;
    If (d1 >= -0.1) And (d1 <= span + 0.1) Then Result := True Else Result := False;
End;

Function StringToFloatSafe(S: String): Double;
Var I: Integer; S_dot, S_comma: String; val: Double; success: Boolean;
Begin
    S_dot := S; S_comma := S;
    For I := 1 To Length(S_dot) Do If S_dot[I] = ',' Then S_dot[I] := '.';
    For I := 1 To Length(S_comma) Do If S_comma[I] = '.' Then S_comma[I] := ',';
    success := False;
    Try val := StrToFloat(S_comma); success := True; Except End;
    If Not success Then Begin Try val := StrToFloat(S_dot); success := True; Except End; End;
    If success Then Result := val Else Result := -1.0;
End;

Function CToMM(C: Integer): Double; Begin Result := C / 393700.787; End;
Function MMToC(M: Double): Integer; Begin Result := Round(M * 393700.787); End;

// --- Hauptprogramm Universal Fillet ---
Procedure CreateUniversalFillet;
Var
    Board                  : IPCB_Board;
    Iterator               : IPCB_BoardIterator;
    Obj_PCB                : IPCB_PCBObject;
    Track1, Track2         : IPCB_Track;
    TheArc                 : IPCB_Arc;
    NewArc                 : IPCB_Arc;
    
    TrackCount, ArcCount   : Integer;
    RunMode                : Integer; 
    
    // GUI & Input
    Form, FormCheck        : TForm;
    LabelInfo              : TLabel;
    EditRadius             : TEdit;
    BtnOk, BtnCancel       : TButton;
    BtnKeep, BtnChange, BtnCancelAction : TButton;
    RadiusVal              : Double;
    InputStr               : String;
    Res                    : Integer;

    // Backup Variablen für Undo-Funktion
    Orig_T1_X1, Orig_T1_Y1, Orig_T1_X2, Orig_T1_Y2 : Integer;
    Orig_T2_X1, Orig_T2_Y1, Orig_T2_X2, Orig_T2_Y2 : Integer;
    Orig_Arc_Start, Orig_Arc_End : Double;

    // Mathe Variablen (Global)
    N_X, N_Y               : Double; 
    E1_X, E1_Y, E2_X, E2_Y : Double; 
    v1x, v1y, v2x, v2y     : Double;
    len1, len2             : Double;
    u1x, u1y, u2x, u2y     : Double;
    dot, theta, alpha, d, h: Double;
    ubx, uby, lenb         : Double;
    Cx, Cy                 : Double;
    T1x, T1y, T2x, T2y     : Double;
    vt1x, vt1y, vt2x, vt2y : Double;
    Angle1, Angle2, diff   : Double;
    StartAngle, EndAngle   : Double;
    
    T1_X, T1_Y, T2_X, T2_Y : Double; 
    Tfar_X, Tfar_Y         : Double;
    Ca_X, Ca_Y, Ra         : Double;
    As_X, As_Y, Ae_X, Ae_Y : Double;
    NodeIsTrack1           : Boolean;
    NodeIsArcStart         : Boolean;
    ut_X, ut_Y             : Double; 
    ta_X, ta_Y             : Double;
    ucn_X, ucn_Y           : Double;
    nt_X, nt_Y, n1_X, n1_Y : Double;
    len                    : Double;
    loopIdx, tIdx          : Integer;
    sign, R_eff            : Double;
    w_X, w_Y               : Double;
    A, B, C_math, Discr    : Double; 
    t1, t2, t_cand         : Double;
    Best_t                 : Double;
    Best_Cf_X, Best_Cf_Y   : Double;
    Best_Ap_X, Best_Ap_Y   : Double;
    Best_Ap_Angle          : Double;
    HasSolution            : Boolean;
    v_X, v_Y               : Double;
    Ap_X, Ap_Y, Ap_Angle   : Double;
    Tp_X, Tp_Y             : Double;
    AngT, AngA, DiffA      : Double;
    FStart, FEnd           : Double;
Begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;

    Track1 := Nil; Track2 := Nil; TheArc := Nil;
    TrackCount := 0; ArcCount := 0;

    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eTrackObject, eArcObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);

    Obj_PCB := Iterator.FirstPCBObject;
    While Obj_PCB <> Nil Do
    Begin
        If Obj_PCB.Selected Then
        Begin
            If Obj_PCB.ObjectId = eTrackObject Then 
            Begin
                Inc(TrackCount);
                If TrackCount = 1 Then Track1 := Obj_PCB Else If TrackCount = 2 Then Track2 := Obj_PCB;
            End
            Else If Obj_PCB.ObjectId = eArcObject Then 
            Begin
                Inc(ArcCount);
                If ArcCount = 1 Then TheArc := Obj_PCB;
            End;
            
            // --- HIER IST DER TURBO-BOOST ---
            // Sobald wir eine gültige Kombination haben, brechen wir die zeitraubende Suche sofort ab!
            If (TrackCount = 2) And (ArcCount = 0) Then Break; 
            If (TrackCount = 1) And (ArcCount = 1) Then Break;
        End;
        Obj_PCB := Iterator.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(Iterator);

    RunMode := 0;
    If (TrackCount = 2) And (ArcCount = 0) Then RunMode := 1
    Else If (TrackCount = 1) And (ArcCount = 1) Then RunMode := 2
    Else Begin ShowMessage('Bitte wähle entweder genau ZWEI verbundene Tracks ODER genau EINEN Track und EINEN Arc aus!'); Exit; End;

    InputStr := '1.0'; // Startwert merken

    // --- DIE GROSSE SCHLEIFE ---
    While True Do 
    Begin
        Form := TForm.Create(Nil);
        If RunMode = 1 Then Form.Caption := 'Track+Track Fillet' Else Form.Caption := 'Track+Arc Fillet';
        Form.Width := 250; Form.Height := 150; Form.Position := poScreenCenter;

        LabelInfo := TLabel.Create(Form); LabelInfo.Parent := Form; LabelInfo.Caption := 'Radius in mm:'; LabelInfo.Left := 20; LabelInfo.Top := 15;
        EditRadius := TEdit.Create(Form); EditRadius.Parent := Form; EditRadius.Text := InputStr; EditRadius.Left := 20; EditRadius.Top := 35; EditRadius.Width := 190;
        BtnOk := TButton.Create(Form); BtnOk.Parent := Form; BtnOk.Caption := 'OK'; BtnOk.ModalResult := mrOk; BtnOk.Left := 20; BtnOk.Top := 75;
        BtnCancel := TButton.Create(Form); BtnCancel.Parent := Form; BtnCancel.Caption := 'Abbrechen'; BtnCancel.ModalResult := mrCancel; BtnCancel.Left := 110; BtnCancel.Top := 75;

        If Form.ShowModal = mrOk Then Begin InputStr := EditRadius.Text; Form.Free; End Else Begin Form.Free; Exit; End;

        RadiusVal := StringToFloatSafe(InputStr);
        If RadiusVal <= 0.0 Then Begin ShowMessage('Ungültiger Radius! Muss größer als 0 sein.'); Continue; End;

        Orig_T1_X1 := Track1.X1; Orig_T1_Y1 := Track1.Y1; Orig_T1_X2 := Track1.X2; Orig_T1_Y2 := Track1.Y2;
        If RunMode = 1 Then Begin
            Orig_T2_X1 := Track2.X1; Orig_T2_Y1 := Track2.Y1; Orig_T2_X2 := Track2.X2; Orig_T2_Y2 := Track2.Y2;
        End Else Begin
            Orig_Arc_Start := TheArc.StartAngle; Orig_Arc_End := TheArc.EndAngle;
        End;

        // =================================================================
        // MODUS 1: TRACK + TRACK
        // =================================================================
        If RunMode = 1 Then 
        Begin
            If (Track1.X1 = Track2.X1) And (Track1.Y1 = Track2.Y1) Then Begin
                N_X := CToMM(Track1.X1); N_Y := CToMM(Track1.Y1);
                E1_X := CToMM(Track1.X2); E1_Y := CToMM(Track1.Y2); E2_X := CToMM(Track2.X2); E2_Y := CToMM(Track2.Y2);
            End Else If (Track1.X1 = Track2.X2) And (Track1.Y1 = Track2.Y2) Then Begin
                N_X := CToMM(Track1.X1); N_Y := CToMM(Track1.Y1);
                E1_X := CToMM(Track1.X2); E1_Y := CToMM(Track1.Y2); E2_X := CToMM(Track2.X1); E2_Y := CToMM(Track2.Y1);
            End Else If (Track1.X2 = Track2.X1) And (Track1.Y2 = Track2.Y1) Then Begin
                N_X := CToMM(Track1.X2); N_Y := CToMM(Track1.Y2);
                E1_X := CToMM(Track1.X1); E1_Y := CToMM(Track1.Y1); E2_X := CToMM(Track2.X2); E2_Y := CToMM(Track2.Y2);
            End Else If (Track1.X2 = Track2.X2) And (Track1.Y2 = Track2.Y2) Then Begin
                N_X := CToMM(Track1.X2); N_Y := CToMM(Track1.Y2);
                E1_X := CToMM(Track1.X1); E1_Y := CToMM(Track1.Y1); E2_X := CToMM(Track2.X1); E2_Y := CToMM(Track2.Y1);
            End Else Begin ShowMessage('Die Tracks sind nicht an ihren Endpunkten verbunden!'); Exit; End;

            v1x := E1_X - N_X; v1y := E1_Y - N_Y; v2x := E2_X - N_X; v2y := E2_Y - N_Y;
            len1 := Sqrt(v1x*v1x + v1y*v1y); len2 := Sqrt(v2x*v2x + v2y*v2y);
            If (len1 = 0) Or (len2 = 0) Then Begin ShowMessage('Fehler: Eine Track-Länge ist 0!'); Exit; End;

            u1x := v1x / len1; u1y := v1y / len1; u2x := v2x / len2; u2y := v2y / len2;
            dot := u1x*u2x + u1y*u2y;
            If dot > 0.9999 Then Begin ShowMessage('Tracks sind parallel!'); Exit; End;
            If dot < -0.9999 Then Begin ShowMessage('Tracks liegen in einer Linie (180°)'); Exit; End;

            theta := ArcCos(dot); alpha := theta / 2.0;
            d := RadiusVal / (Sin(alpha) / Cos(alpha)); h := RadiusVal / Sin(alpha);

            If (d > len1) Or (d > len2) Then Begin ShowMessage('Radius zu groß! Er überlappt die Leiterbahnen.'); Continue; End;

            T1x := N_X + u1x * d; T1y := N_Y + u1y * d; T2x := N_X + u2x * d; T2y := N_Y + u2y * d;
            ubx := u1x + u2x; uby := u1y + u2y; lenb := Sqrt(ubx*ubx + uby*uby);
            ubx := ubx / lenb; uby := uby / lenb;
            Cx := N_X + ubx * h; Cy := N_Y + uby * h;

            vt1x := T1x - Cx; vt1y := T1y - Cy; vt2x := T2x - Cx; vt2y := T2y - Cy;
            Angle1 := ArcTan2(vt1y, vt1x) * 180.0 / MyPI; Angle2 := ArcTan2(vt2y, vt2x) * 180.0 / MyPI;
            If Angle1 < 0 Then Angle1 := Angle1 + 360.0; If Angle2 < 0 Then Angle2 := Angle2 + 360.0;
            diff := Angle2 - Angle1; If diff < 0 Then diff := diff + 360.0;

            If diff < 180.0 Then Begin StartAngle := Angle1; EndAngle := Angle2; End 
            Else Begin StartAngle := Angle2; EndAngle := Angle1; End;

            NewArc := PCBServer.PCBObjectFactory(eArcObject, eNoDimension, eCreate_Default);
            NewArc.XCenter := MMToC(Cx); NewArc.YCenter := MMToC(Cy);
            NewArc.Radius := MMToC(RadiusVal);
            NewArc.StartAngle := StartAngle; NewArc.EndAngle := EndAngle;
            NewArc.Layer := Track1.Layer;
            NewArc.Net := Track1.Net; 
            Try NewArc.LineWidth := Track1.Width; Except Try NewArc.Width := Track1.Width; Except End; End;
            Board.AddPCBObject(NewArc);

            If (Track1.X1 = MMToC(N_X)) And (Track1.Y1 = MMToC(N_Y)) Then Begin Track1.X1 := MMToC(T1x); Track1.Y1 := MMToC(T1y); End 
            Else Begin Track1.X2 := MMToC(T1x); Track1.Y2 := MMToC(T1y); End;

            If (Track2.X1 = MMToC(N_X)) And (Track2.Y1 = MMToC(N_Y)) Then Begin Track2.X1 := MMToC(T2x); Track2.Y1 := MMToC(T2y); End 
            Else Begin Track2.X2 := MMToC(T2x); Track2.Y2 := MMToC(T2y); End;
        End
        
        // =================================================================
        // MODUS 2: TRACK + ARC
        // =================================================================
        Else If RunMode = 2 Then 
        Begin
            T1_X := CToMM(Track1.X1); T1_Y := CToMM(Track1.Y1); T2_X := CToMM(Track1.X2); T2_Y := CToMM(Track1.Y2);
            Ca_X := CToMM(TheArc.XCenter); Ca_Y := CToMM(TheArc.YCenter); Ra   := CToMM(TheArc.Radius);
            
            As_X := Ca_X + Ra * Cos(TheArc.StartAngle * MyPI / 180.0); As_Y := Ca_Y + Ra * Sin(TheArc.StartAngle * MyPI / 180.0);
            Ae_X := Ca_X + Ra * Cos(TheArc.EndAngle * MyPI / 180.0); Ae_Y := Ca_Y + Ra * Sin(TheArc.EndAngle * MyPI / 180.0);

            If Dist(T1_X, T1_Y, As_X, As_Y) < 0.05 Then Begin N_X:=T1_X; N_Y:=T1_Y; Tfar_X:=T2_X; Tfar_Y:=T2_Y; NodeIsTrack1:=True; NodeIsArcStart:=True; End
            Else If Dist(T1_X, T1_Y, Ae_X, Ae_Y) < 0.05 Then Begin N_X:=T1_X; N_Y:=T1_Y; Tfar_X:=T2_X; Tfar_Y:=T2_Y; NodeIsTrack1:=True; NodeIsArcStart:=False; End
            Else If Dist(T2_X, T2_Y, As_X, As_Y) < 0.05 Then Begin N_X:=T2_X; N_Y:=T2_Y; Tfar_X:=T1_X; Tfar_Y:=T1_Y; NodeIsTrack1:=False; NodeIsArcStart:=True; End
            Else If Dist(T2_X, T2_Y, Ae_X, Ae_Y) < 0.05 Then Begin N_X:=T2_X; N_Y:=T2_Y; Tfar_X:=T1_X; Tfar_Y:=T1_Y; NodeIsTrack1:=False; NodeIsArcStart:=False; End
            Else Begin ShowMessage('Track und Arc sind nicht an ihren Endpunkten verbunden!'); Exit; End;

            ut_X := Tfar_X - N_X; ut_Y := Tfar_Y - N_Y;
            len := Sqrt(ut_X*ut_X + ut_Y*ut_Y); If len = 0 Then Exit;
            ut_X := ut_X / len; ut_Y := ut_Y / len;

            ucn_X := N_X - Ca_X; ucn_Y := N_Y - Ca_Y;
            len := Sqrt(ucn_X*ucn_X + ucn_Y*ucn_Y); ucn_X := ucn_X / len; ucn_Y := ucn_Y / len;
            If NodeIsArcStart Then Begin ta_X := -ucn_Y; ta_Y := ucn_X; End Else Begin ta_X := ucn_Y; ta_Y := -ucn_X; End;                  

            n1_X := -ut_Y; n1_Y := ut_X;
            If (n1_X * ta_X + n1_Y * ta_Y) > 0 Then Begin nt_X := n1_X; nt_Y := n1_Y; End Else Begin nt_X := -n1_X; nt_Y := -n1_Y; End;

            Best_t := 999999.0; HasSolution := False;

            For loopIdx := 0 To 1 Do
            Begin
                If loopIdx = 0 Then sign := -1.0 Else sign := 1.0;
                R_eff := Ra + (sign * RadiusVal);
                If R_eff > 0 Then 
                Begin
                    w_X := (N_X + RadiusVal * nt_X) - Ca_X; w_Y := (N_Y + RadiusVal * nt_Y) - Ca_Y;
                    A := 1.0; B := 2.0 * (w_X * ut_X + w_Y * ut_Y); C_math := (w_X*w_X + w_Y*w_Y) - (R_eff * R_eff);
                    Discr := (B*B) - (4.0 * A * C_math);

                    If Discr >= 0 Then
                    Begin
                        t1 := (-B + Sqrt(Discr)) / 2.0; t2 := (-B - Sqrt(Discr)) / 2.0;
                        For tIdx := 1 To 2 Do
                        Begin
                            If tIdx = 1 Then t_cand := t1 Else t_cand := t2;
                            If (t_cand > 0.001) And (t_cand < Dist(N_X, N_Y, Tfar_X, Tfar_Y)) Then
                            Begin
                                v_X := (N_X + RadiusVal * nt_X + t_cand * ut_X) - Ca_X;
                                v_Y := (N_Y + RadiusVal * nt_Y + t_cand * ut_Y) - Ca_Y;
                                len := Sqrt(v_X*v_X + v_Y*v_Y);
                                Ap_X := Ca_X + Ra * (v_X / len); Ap_Y := Ca_Y + Ra * (v_Y / len);
                                Ap_Angle := ArcTan2(Ap_Y - Ca_Y, Ap_X - Ca_X) * 180.0 / MyPI;
                                If Ap_Angle < 0 Then Ap_Angle := Ap_Angle + 360.0;

                                If IsAngleBetween(Ap_Angle, TheArc.StartAngle, TheArc.EndAngle) Then
                                Begin
                                    If t_cand < Best_t Then
                                    Begin
                                        Best_t := t_cand; Best_Cf_X := N_X + RadiusVal * nt_X + t_cand * ut_X;
                                        Best_Cf_Y := N_Y + RadiusVal * nt_Y + t_cand * ut_Y; Best_Ap_X := Ap_X;
                                        Best_Ap_Y := Ap_Y; Best_Ap_Angle := Ap_Angle; HasSolution := True;
                                    End;
                                End;
                            End;
                        End;
                    End;
                End;
            End;

            If Not HasSolution Then Begin ShowMessage('Radius ist zu groß oder geometrisch unmöglich!'); Continue; End;

            Tp_X := N_X + Best_t * ut_X; Tp_Y := N_Y + Best_t * ut_Y;
            If NodeIsTrack1 Then Begin Track1.X1 := MMToC(Tp_X); Track1.Y1 := MMToC(Tp_Y); End
            Else Begin Track1.X2 := MMToC(Tp_X); Track1.Y2 := MMToC(Tp_Y); End;

            If NodeIsArcStart Then TheArc.StartAngle := Best_Ap_Angle Else TheArc.EndAngle := Best_Ap_Angle;

            AngT := ArcTan2(Tp_Y - Best_Cf_Y, Tp_X - Best_Cf_X) * 180.0 / MyPI;
            AngA := ArcTan2(Best_Ap_Y - Best_Cf_Y, Best_Ap_X - Best_Cf_X) * 180.0 / MyPI;
            If AngT < 0 Then AngT := AngT + 360.0; If AngA < 0 Then AngA := AngA + 360.0;
            DiffA := AngA - AngT;
            While DiffA < 0 Do DiffA := DiffA + 360.0; While DiffA >= 360.0 Do DiffA := DiffA - 360.0;

            If DiffA < 180.0 Then Begin FStart := AngT; FEnd := AngA; End Else Begin FStart := AngA; FEnd := AngT; End;

            NewArc := PCBServer.PCBObjectFactory(eArcObject, eNoDimension, eCreate_Default);
            NewArc.XCenter := MMToC(Best_Cf_X); NewArc.YCenter := MMToC(Best_Cf_Y);
            NewArc.Radius := MMToC(RadiusVal);
            NewArc.StartAngle := FStart; NewArc.EndAngle := FEnd;
            NewArc.Layer := Track1.Layer;
            NewArc.Net := Track1.Net; 
            Try NewArc.LineWidth := Track1.Width; Except Try NewArc.Width := Track1.Width; Except End; End;
            Board.AddPCBObject(NewArc);
        End;

        // --- BILD AKTUALISIEREN FÜR VORSCHAU ---
        Try Client.SendMessage('PCB:Zoom', 'Action=Redraw' , 255, Client.CurrentView); Except End;

        // --- INTERAKTIVE PRÜFUNG (Behalten oder Zurück?) ---
        FormCheck := TForm.Create(Nil);
        FormCheck.Caption := 'Ergebnis überprüfen';
        FormCheck.Width := 290; FormCheck.Height := 120; FormCheck.Position := poScreenCenter;

        BtnKeep := TButton.Create(FormCheck);
        BtnKeep.Parent := FormCheck; BtnKeep.Caption := 'Behalten'; BtnKeep.ModalResult := mrOk; BtnKeep.Left := 15; BtnKeep.Top := 30; BtnKeep.Width := 80;

        BtnChange := TButton.Create(FormCheck);
        BtnChange.Parent := FormCheck; BtnChange.Caption := 'Ändern'; BtnChange.ModalResult := mrRetry; BtnChange.Left := 105; BtnChange.Top := 30; BtnChange.Width := 80;

        BtnCancelAction := TButton.Create(FormCheck);
        BtnCancelAction.Parent := FormCheck; BtnCancelAction.Caption := 'Abbrechen'; BtnCancelAction.ModalResult := mrCancel; BtnCancelAction.Left := 195; BtnCancelAction.Top := 30; BtnCancelAction.Width := 80;

        Res := FormCheck.ShowModal;
        FormCheck.Free;

        // --- ENTSCHEIDUNG AUSWERTEN ---
        If Res = mrOk Then 
        Begin
            Break; // User ist zufrieden -> Beende die Schleife!
        End 
        Else 
        Begin
            Track1.X1 := Orig_T1_X1; Track1.Y1 := Orig_T1_Y1; Track1.X2 := Orig_T1_X2; Track1.Y2 := Orig_T1_Y2;
            If RunMode = 1 Then Begin
                Track2.X1 := Orig_T2_X1; Track2.Y1 := Orig_T2_Y1; Track2.X2 := Orig_T2_X2; Track2.Y2 := Orig_T2_Y2;
            End Else Begin
                TheArc.StartAngle := Orig_Arc_Start; TheArc.EndAngle := Orig_Arc_End;
            End;
            
            Board.RemovePCBObject(NewArc); 
            Try Client.SendMessage('PCB:Zoom', 'Action=Redraw' , 255, Client.CurrentView); Except End;

            If Res = mrCancel Then Exit; 
        End;
    End;
End;