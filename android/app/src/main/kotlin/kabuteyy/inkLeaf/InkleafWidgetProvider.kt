package kabuteyy.inkLeaf

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Inkleaf's home-screen widget: quick-capture buttons (note, checklist,
 * voice, scan) and up to three pinned notes. The app writes the pinned
 * notes into [widgetData]; each tap opens the app with an inkleaf:// link
 * that it turns into the right screen.
 */
class InkleafWidgetProvider : HomeWidgetProvider() {

    private val pinnedRows = intArrayOf(R.id.pinned_0, R.id.pinned_1, R.id.pinned_2)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.inkleaf_widget)

            fun open(viewId: Int, link: String) = views.setOnClickPendingIntent(
                viewId,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse(link),
                ),
            )

            open(R.id.widget_title, "inkleaf://home")
            open(R.id.new_note, "inkleaf://new?mode=text")
            open(R.id.new_checklist, "inkleaf://new?mode=checklist")
            open(R.id.new_recording, "inkleaf://new?mode=record")
            open(R.id.new_scan, "inkleaf://new?mode=scan")

            val pinned = widgetData.getInt("pinned_count", 0)
            pinnedRows.forEachIndexed { i, row ->
                val id = widgetData.getString("pinned_id_$i", null)
                val title = widgetData.getString("pinned_title_$i", null)
                if (i < pinned && id != null && title != null) {
                    views.setTextViewText(row, "📌  $title")
                    views.setViewVisibility(row, View.VISIBLE)
                    open(row, "inkleaf://note?id=${Uri.encode(id)}")
                } else {
                    views.setViewVisibility(row, View.GONE)
                }
            }
            views.setViewVisibility(
                R.id.pinned_empty,
                if (pinned == 0) View.VISIBLE else View.GONE,
            )

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
