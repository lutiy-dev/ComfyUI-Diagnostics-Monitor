# Transparent, always-on-top HUD window for the existing Windows Dashboard.
# Visualization only: reads dashboard state and does not change the collector or ComfyUI.
function Initialize-Hud {
    $script:hudVisible=$false
    $script:hudDragging=$false
    $script:hud=New-Object System.Windows.Forms.Form
    $script:hud.Name='ComfyUICompactHUD'
    $script:hud.Text='ComfyUI Diagnostics HUD'
    $script:hud.FormBorderStyle=[System.Windows.Forms.FormBorderStyle]::None
    $script:hud.ShowInTaskbar=$false
    $script:hud.TopMost=$true
    $script:hud.StartPosition=[System.Windows.Forms.FormStartPosition]::Manual
    $script:hud.Size=[Drawing.Size]::new(420,160)
    $script:hud.BackColor=[Drawing.Color]::Magenta
    $script:hud.TransparencyKey=[Drawing.Color]::Magenta
    $script:hud.KeyPreview=$true
    $bounds=[System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $script:hud.Location=[Drawing.Point]::new(($bounds.Right-440),($bounds.Top+24))

    $script:hud.Add_Paint({
        param($sender,$e)
        $g=$e.Graphics
        $g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $font=New-Object Drawing.Font('Segoe UI',11,[Drawing.FontStyle]::Bold)
        $small=New-Object Drawing.Font('Segoe UI',9)
        $white=[Drawing.Brushes]::White
        $cyan=New-Object Drawing.Pen([Drawing.Color]::DeepSkyBlue,2)
        $orange=New-Object Drawing.Pen([Drawing.Color]::Orange,2)
        try {
            $label="GPU: no data"
            $detail="VRAM: no data"
            if ($null -ne $script:gpu -and $script:gpu.Text -match 'Load:') { $label=$script:gpu.Text }
            if ($null -ne $script:vram) { $detail=$script:vram.Text }
            $cyanBrush=New-Object Drawing.SolidBrush([Drawing.Color]::DeepSkyBlue)
            $orangeBrush=New-Object Drawing.SolidBrush([Drawing.Color]::Orange)
            try {
                $g.DrawString($label,$font,$cyanBrush,8,3)
                $g.DrawString($detail,$small,$orangeBrush,8,28)
            } finally { $cyanBrush.Dispose(); $orangeBrush.Dispose() }
            $g.DrawString("ComfyUI: "+$script:session+" | "+$script:wsState,$small,$white,8,47)
            $stepText=if ($script:stepTotal -gt 0) { "Step $($script:step)/$($script:stepTotal)" } else { "Node: $($script:activeNode)" }
            $g.DrawString($stepText,$small,$white,8,66)
            $left=10; $top=94; $width=395; $height=52
            foreach ($metric in @(@('GPU %',$cyan),@('VRAM %',$orange))) {
                $series=$script:chart.Series[$metric[0]]
                $count=$series.Points.Count
                if ($count -lt 2) { continue }
                $start=[math]::Max(0,$count-80)
                $visible=$count-$start
                for ($i=1;$i -lt $visible;$i++) {
                    $a=[math]::Max(0,[math]::Min(100,[double]$series.Points[$start+$i-1].YValues[0]))
                    $b=[math]::Max(0,[math]::Min(100,[double]$series.Points[$start+$i].YValues[0]))
                    $x1=[single]($left+($i-1)*$width/($visible-1))
                    $x2=[single]($left+$i*$width/($visible-1))
                    $y1=[single]($top+$height*(1-$a/100))
                    $y2=[single]($top+$height*(1-$b/100))
                    $g.DrawLine($metric[1],$x1,$y1,$x2,$y2)
                }
            }
        } finally {
            $font.Dispose();$small.Dispose();$cyan.Dispose();$orange.Dispose()
        }
    })
    $script:hud.Add_MouseDown({
        param($sender,$e)
        if ($e.Button -eq [Windows.Forms.MouseButtons]::Left) {
            $script:hudDragging=$true
            $script:hudDragStart=[Drawing.Point]::new($e.X,$e.Y)
        }
    })
    $script:hud.Add_MouseMove({
        param($sender,$e)
        if ($script:hudDragging) {
            $screenPos=[Windows.Forms.Cursor]::Position
            $script:hud.Location=[Drawing.Point]::new(($screenPos.X-$script:hudDragStart.X),($screenPos.Y-$script:hudDragStart.Y))
        }
    })
    $script:hud.Add_MouseUp({$script:hudDragging=$false})
    $script:hud.Add_MouseDoubleClick({Switch-ToFullDashboard})
    $script:hud.Add_KeyDown({param($sender,$e);if ($e.KeyCode -eq [Windows.Forms.Keys]::F9) { Switch-ToFullDashboard }})
}
function Switch-ToHud {
    if ($script:hudVisible) { return }
    # Keep the full dashboard visible until the HUD has a window handle.
    # If HUD creation fails, do not leave the user with no visible window.
    try {
        $script:hud.Show()
        if (-not $script:hud.Visible) { throw 'HUD did not become visible' }
        $script:hud.BringToFront()
        $script:hudVisible=$true
        $script:form.Hide()
    } catch {
        $script:hudVisible=$false
        $script:hud.Hide()
        $script:form.WindowState=[Windows.Forms.FormWindowState]::Normal
        $script:form.Show()
        $script:form.Activate()
        Write-Warning 'HUD unavailable; Dashboard restored'
    }
}
function Switch-ToFullDashboard {
    if (-not $script:hudVisible) { return }
    $script:hudVisible=$false
    $script:hudDragging=$false
    $script:hud.Hide()
    $script:form.WindowState=[Windows.Forms.FormWindowState]::Normal
    $script:form.Show()
    $script:form.Activate()
}
