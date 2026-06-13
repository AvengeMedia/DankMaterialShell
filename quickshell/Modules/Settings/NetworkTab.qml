pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

NetworkPageContainer {
    id: networkTab

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    NetworkOverviewPage {}
}
